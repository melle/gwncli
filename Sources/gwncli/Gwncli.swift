// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import ArgumentParser
import Combine
import Foundation
import FoundationExtensions


@main
struct Gwncli: ParsableCommand {
    
    /// Common options for all commands
    struct CommonOptions: ParsableArguments {
        @Option(help: "URL of the Grandstream web interface - preferrable is the bonjour-URL - i.e. https://gwn_c074ad7b2950.local")
        var url: String
        @Option(help: "Username to use at login, usually admin")
        var username: String
        @Option(help: "Password to be used at login, i.e. \(randomPassword())")
        var password: String
        @Option(help: "Path to an aliases file, i.e. ~/.gwnaliases.txt")
        var aliases: String?

        /// Generates an 8 character pseudo random password. Just to have a different password in the command line help every time you call it 🤡
        static func randomPassword() -> String {
            return String((0..<8).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        }
    }

    static var configuration = CommandConfiguration(
        // Optional abstracts and discussions are used for help output.
        abstract: "A command-line utility for Grandstream WiFi access points.",
        version: "1.0.0", //  automatic '--version' support.
        subcommands: [ListRules.self, AddOrUpdate.self, DeleteRule.self],
        defaultSubcommand: ListRules.self)
}

// MARK: - List rules

extension Gwncli {

    struct ListRules: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "Lists currently active bandwidth rules."
        )
        
        @OptionGroup var options: CommonOptions

        mutating func run() throws {
            guard let gwnUrl = URL(string: options.url) else {
                throw GwnError.freeForm("Invalid url \(options.url)")
            }
            var cancellables: Set<AnyCancellable> = .init()
            let session = URLSession(configuration: URLSession.shared.configuration,
                                     delegate: TlsWarningsIgnoringUrlSessionDelegate(),
                                     delegateQueue: nil)
            let context = GwnContext(session: session,
                                     url: gwnUrl,
                                     userName: options.username,
                                     password: options.password,
                                     aliases: options.aliases)
            GWN.readAliases(context: context)
                .flatMap { GWN.acquireSession(context: $0) }
                .flatMap { GWN.getConfiguration(context: $0) }
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case let .failure(gwnError):
                        ListRules.exit(withError: gwnError)
                    case .finished:
                        ListRules.exit()
                    }
                }, receiveValue: { configuration in
                    print(configuration.bandwidthRulesFormatted(aliases: context.aliases))
                })
                .store(in: &cancellables)
            RunLoop.current.run()
        }
    }
}

// MARK: - Add / update rule

extension Gwncli {

    struct AddOrUpdate: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Adds or updates a bandwidth rule for the given address."
        )

        @OptionGroup var options: CommonOptions

        @Option(help: "Hardware address of the device, i.e. AA:BB:CC:DD:EE:FF")
        var mac: String
        @Option(help: "SSID-id where the rule should be applied (must be an existing SSID, i.e. ssid0)")
        var ssid: String
        @Option(help: "Download-Rate (Mbps/Kbps), i.e. 128Kbps")
        var drate: String
        @Option(help: "Upload-Rate (Mbps/Kbps), i.e. 1Mbps")
        var urate: String

        func run() throws {
            guard let gwnUrl = URL(string: options.url) else {
                throw GwnError.freeForm("Invalid url \(options.url)")
            }
            // GWN is very picky about the units, only Mbps and Kbps in the right case are allowed.
            guard let regex = try? NSRegularExpression(pattern: "[0-9]*[M,K]bps"),
                  1 == regex.numberOfMatches(in: drate, range: NSRange(location: 0, length: drate.utf16.count)),
                  1 == regex.numberOfMatches(in: urate, range: NSRange(location: 0, length: urate.utf16.count))
            else {
                throw GwnError.freeForm("Upload/Download rate must be expressed as Mbps or Kbps, i.e 64Kbps")
            }
            
            var cancellables: Set<AnyCancellable> = .init()
            let session = URLSession(configuration: URLSession.shared.configuration,
                                     delegate: TlsWarningsIgnoringUrlSessionDelegate(),
                                     delegateQueue: nil)
            let context = GwnContext(session: session,
                                     url: gwnUrl,
                                     userName: options.username,
                                     password: options.password,
                                     aliases: options.aliases)
            GWN.readAliases(context: context)
                .flatMap { GWN.acquireSession(context: $0) }
                .flatMap { GWN.addOrUpdateRule(context: $0, mac: mac, ssidId: ssid, drate: drate, urate: urate) }
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case let .failure(gwnError):
                        ListRules.exit(withError: gwnError)
                    case .finished:
                        ListRules.exit()
                    }
                }, receiveValue: { configuration in
                    print(configuration.bandwidthRulesFormatted(aliases: context.aliases))
                })
                .store(in: &cancellables)
            RunLoop.current.run()

        }
    }
}

// MARK: - Delete rule

extension Gwncli {
    struct DeleteRule: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Removed a bandwidth rule for the given address."
        )
        
        @OptionGroup var options: CommonOptions

        @Option(help: "Name of the rule to delete (use 'list' subcommand to see all rules)")
        var ruleName: String
        

        func run() throws {
            guard let gwnUrl = URL(string: options.url) else {
                throw GwnError.freeForm("Invalid url \(options.url)")
            }
            var cancellables: Set<AnyCancellable> = .init()
            
            let session = URLSession(configuration: URLSession.shared.configuration,
                                     delegate: TlsWarningsIgnoringUrlSessionDelegate(),
                                     delegateQueue: nil)
            let context = GwnContext(session: session,
                                     url: gwnUrl,
                                     userName: options.username,
                                     password: options.password,
                                     aliases: options.aliases)
            GWN.readAliases(context: context)
                .flatMap { GWN.acquireSession(context: $0) }
                .flatMap { GWN.deleteRule(context: $0, ruleName: ruleName) }
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case let .failure(gwnError):
                        DeleteRule.exit(withError: gwnError)
                    case .finished:
                        DeleteRule.exit()
                    }
                }, receiveValue: { configuration in
                    print(configuration.bandwidthRulesFormatted(aliases: context.aliases))
                })
                .store(in: &cancellables)
            RunLoop.current.run()
        }
    }
}
