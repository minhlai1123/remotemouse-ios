import SwiftUI
import RemoteMouseCore

/// SwiftUI View displaying Paired Devices History for iOS.
/// Allows selecting a device for auto-reconnect or forgetting devices locally.
public struct PairedHistoryView: View {
    @ObservedObject var historyManager = PairedDeviceHistoryManager.shared
    public let onSelectDevice: (PairedDevice) -> Void
    public let onScanQR: () -> Void

    @State private var showingForgetAlert = false
    @State private var deviceToForget: PairedDevice?

    public init(
        onSelectDevice: @escaping (PairedDevice) -> Void,
        onScanQR: @escaping () -> Void
    ) {
        self.onSelectDevice = onSelectDevice
        self.onScanQR = onScanQR
    }

    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Thiết bị đã ghép đôi")) {
                    if historyManager.devices.isEmpty {
                        Text("Chưa có thiết bị nào được lưu. Quét mã QR trên màn hình máy tính để kết nối.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(historyManager.devices) { device in
                            Button(action: {
                                onSelectDevice(device)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(device.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("\(device.lastAddress):\(device.port)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("Vân tay: \(device.fingerprint.prefix(8))...")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deviceToForget = device
                                    showingForgetAlert = true
                                } label: {
                                    Label("Quên", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(action: onScanQR) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Quét mã QR máy tính mới")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Lịch sử kết nối")
            .alert(isPresented: $showingForgetAlert) {
                Alert(
                    title: Text("Quên thiết bị?"),
                    message: Text("Xóa thông tin '\(deviceToForget?.name ?? "")' khỏi điện thoại. Khóa xác thực trên máy này sẽ bị hủy bỏ."),
                    primaryButton: .destructive(Text("Quên")) {
                        if let d = deviceToForget {
                            historyManager.forgetDevice(id: d.id)
                        }
                    },
                    secondaryButton: .cancel(Text("Hủy"))
                )
            }
        }
    }
}
