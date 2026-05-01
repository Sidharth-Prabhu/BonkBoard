//
//  AppleSiliconImpactMonitor.swift
//  BonkBoard
//
//  Created by Sidharth Prabhu on 2026-05-01.
//

import Foundation
import Combine
import IOKit
import IOKit.hid

@MainActor
final class AppleSiliconImpactMonitor: ObservableObject {
    @Published private(set) var impactDetected = false
    @Published private(set) var statusText = "Starting accelerometer..."
    @Published private(set) var latestAcceleration: Acceleration?
    @Published private(set) var latestSpike = 0.0
    @Published private(set) var impactEventID = 0

    struct Acceleration {
        let x: Double
        let y: Double
        let z: Double

        var magnitude: Double {
            sqrt(x * x + y * y + z * z)
        }
    }

    private var devices: [IOHIDDevice] = []
    private var reportBuffers: [UnsafeMutablePointer<UInt8>] = []
    private var previousAcceleration: Acceleration?
    private var lastImpactDate = Date.distantPast
    private var clearImpactTask: Task<Void, Never>?
    private var isMonitoring = false

    private var lastUIPublishDate = Date.distantPast
    private let uiPublishInterval: TimeInterval = 1.0 / 30.0 // 30 Hz cap
    private let spikeEpsilon: Double = 0.002 // only publish meaningful changes

    private var impactThreshold = 0.052

    func start() {
        guard !isMonitoring else { return }

        wakeSPUDrivers()

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(ImpactSensorConstants.deviceServiceName),
            &iterator
        )

        guard result == KERN_SUCCESS else {
            statusText = "Unable to scan Apple Silicon accelerometer devices."
            return
        }

        defer {
            IOObjectRelease(iterator)
        }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer {
                IOObjectRelease(service)
            }

            guard propertyInt(service, key: "PrimaryUsagePage") == ImpactSensorConstants.vendorUsagePage,
                  propertyInt(service, key: "PrimaryUsage") == ImpactSensorConstants.accelerometerUsage,
                  let hidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, service)
            else {
                continue
            }

            let openResult = IOHIDDeviceOpen(hidDevice, IOOptionBits(kIOHIDOptionsTypeNone))
            guard openResult == kIOReturnSuccess else {
                statusText = "Accelerometer found, but BonkBoard could not open it. Try running outside the app sandbox and with administrator privileges."
                continue
            }

            let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: ImpactSensorConstants.reportBufferSize)
            reportBuffer.initialize(repeating: 0, count: ImpactSensorConstants.reportBufferSize)

            IOHIDDeviceRegisterInputReportCallback(
                hidDevice,
                reportBuffer,
                ImpactSensorConstants.reportBufferSize,
                accelerometerCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
            IOHIDDeviceScheduleWithRunLoop(hidDevice, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

            devices.append(hidDevice)
            reportBuffers.append(reportBuffer)
        }

        isMonitoring = !devices.isEmpty
        statusText = isMonitoring ? "Monitoring for impacts" : "No Apple Silicon accelerometer was found."
    }

    func updateImpactThreshold(_ threshold: Double) {
        impactThreshold = threshold
    }

    func stop() {
        clearImpactTask?.cancel()
        clearImpactTask = nil

        for device in devices {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        for reportBuffer in reportBuffers {
            reportBuffer.deallocate()
        }

        devices.removeAll()
        reportBuffers.removeAll()
        previousAcceleration = nil
        isMonitoring = false
        statusText = "Accelerometer stopped"
    }

    deinit {
        for device in devices {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        for reportBuffer in reportBuffers {
            reportBuffer.deallocate()
        }
    }

    fileprivate func handle(report: [UInt8]) {
        guard report.count == ImpactSensorConstants.imuReportLength else { return }

        let acceleration = Acceleration(
            x: scaledInt32(from: report, offset: ImpactSensorConstants.imuDataOffset),
            y: scaledInt32(from: report, offset: ImpactSensorConstants.imuDataOffset + 4),
            z: scaledInt32(from: report, offset: ImpactSensorConstants.imuDataOffset + 8)
        )

        let spike = previousAcceleration.map { previous in
            let dx = acceleration.x - previous.x
            let dy = acceleration.y - previous.y
            let dz = acceleration.z - previous.z
            let axisSpike = max(abs(dx), abs(dy), abs(dz))
            let vectorSpike = sqrt(dx * dx + dy * dy + dz * dz)
            return max(axisSpike, vectorSpike * 0.6)
        } ?? 0

        // Coalesce UI updates to reduce main-thread churn
        let now = Date()
        let shouldPublishTime = now.timeIntervalSince(lastUIPublishDate) >= uiPublishInterval
        let shouldPublishChange = abs(spike - latestSpike) >= spikeEpsilon || latestAcceleration == nil

        if shouldPublishTime && shouldPublishChange {
            latestAcceleration = acceleration
            latestSpike = spike
            lastUIPublishDate = now
        }

        previousAcceleration = acceleration

        if spike >= impactThreshold,
           Date().timeIntervalSince(lastImpactDate) >= ImpactSensorConstants.impactCooldown {
            showImpactDetected()
        }
    }

    private func showImpactDetected() {
        lastImpactDate = Date()
        impactEventID += 1
        impactDetected = true
        statusText = "Impact detected"

        clearImpactTask?.cancel()
        clearImpactTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ImpactSensorConstants.impactVisibleDuration))

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.impactDetected = false
                self?.statusText = "Monitoring for impacts"
            }
        }
    }

    private func wakeSPUDrivers() {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(ImpactSensorConstants.driverServiceName),
            &iterator
        )

        guard result == KERN_SUCCESS else { return }

        defer {
            IOObjectRelease(iterator)
        }

        while case let service = IOIteratorNext(iterator), service != 0 {
            setInt32Property(service, key: "SensorPropertyReportingState", value: 1)
            setInt32Property(service, key: "SensorPropertyPowerState", value: 1)
            setInt32Property(service, key: "ReportInterval", value: ImpactSensorConstants.reportIntervalMicroseconds)
            IOObjectRelease(service)
        }
    }

    private func propertyInt(_ service: io_service_t, key: String) -> Int? {
        guard let property = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber else {
            return nil
        }

        return property.intValue
    }

    private func setInt32Property(_ service: io_service_t, key: String, value: Int32) {
        var mutableValue = value
        guard let number = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &mutableValue) else {
            return
        }

        IORegistryEntrySetCFProperty(service, key as CFString, number)
    }

    private func scaledInt32(from report: [UInt8], offset: Int) -> Double {
        let rawValue = UInt32(report[offset])
            | (UInt32(report[offset + 1]) << 8)
            | (UInt32(report[offset + 2]) << 16)
            | (UInt32(report[offset + 3]) << 24)

        return Double(Int32(bitPattern: rawValue)) / ImpactSensorConstants.valueScale
    }
}

private enum ImpactSensorConstants {
    static let driverServiceName = "AppleSPUHIDDriver"
    static let deviceServiceName = "AppleSPUHIDDevice"
    static let vendorUsagePage = 0xFF00
    static let accelerometerUsage = 3
    static let reportBufferSize = 4096
    static let imuReportLength = 22
    static let imuDataOffset = 6
    static let valueScale = 65_536.0
    static let reportIntervalMicroseconds: Int32 = 16_000
    static let impactCooldown = 0.25
    static let impactVisibleDuration = 2.0
}

private let accelerometerCallback: IOHIDReportCallback = { context, _, _, _, _, report, reportLength in
    guard let context else { return }

    let monitor = Unmanaged<AppleSiliconImpactMonitor>.fromOpaque(context).takeUnretainedValue()
    let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))

    Task { @MainActor in
        monitor.handle(report: bytes)
    }
}
