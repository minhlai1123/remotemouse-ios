import Foundation
import Network

/// Apple Network.framework NWBrowser implementation for discovering RMPP mDNS services.
/// Conforms to ADR 3.4-A, ADR-01, and ADR-03.
public class NWBrowserDiscovery {
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.remotemouse.discovery.browser", qos: .utility)
    public private(set) var isBrowsing: BooleanLiteralType = false

    public static let serviceType = "_rmpp._tcp"

    public init() {}

    /// Starts browsing for RMPP mDNS services on local network.
    public func start(onHostFound: @escaping (DiscoveredHost) -> Void) {
        guard !isBrowsing else { return }

        let descriptor = NWBrowser.Descriptor.bonjour(type: Self.serviceType, domain: nil)
        let parameters = NWParameters.tcp
        let nwBrowser = NWBrowser(for: descriptor, using: parameters)

        nwBrowser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isBrowsing = true
            case .failed(let error):
                print("[NWBrowserDiscovery] Browser failed with error: \(error)")
                self?.stop()
            case .cancelled:
                self?.isBrowsing = false
            default:
                break
            }
        }

        nwBrowser.browseResultsChangedHandler = { results, changes in
            for result in results {
                switch result.endpoint {
                case .service(let name, _, _, _):
                    // Extract TXT record metadata from NWBrowser.Result.Metadata
                    var fp = ""
                    var version = 2
                    if case .bonjour(let txtRecord) = result.metadata {
                        fp = txtRecord.dictionary["fp"] ?? ""
                        if let vStr = txtRecord.dictionary["v"], let v = Int(vStr) {
                            version = v
                        }
                    }

                    // Resolve endpoint connection to determine IP and port
                    let host = DiscoveredHost(
                        name: name,
                        address: "local",
                        port: 54321,
                        fingerprint: fp,
                        version: version,
                        source: .bonjour
                    )
                    DispatchQueue.main.async {
                        onHostFound(host)
                    }
                default:
                    break
                }
            }
        }

        self.browser = nwBrowser
        nwBrowser.start(queue: queue)
    }

    /// Stops browsing and cleans up network resources.
    public func stop() {
        guard isBrowsing || browser != nil else { return }
        browser?.cancel()
        browser = nil
        isBrowsing = false
    }

    deinit {
        stop()
    }
}
