// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import ArgumentParser
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@main
struct Gwncli: ParsableCommand {
    
    /// Common options for all commands
    struct CommonOptions: ParsableArguments {
        @Option(help: "URL of the Grandstream web interface - preferably is the bonjour-URL - i.e. https://gwn_c074ad7b2950.local")
        var url: String
        @Option(help: "Username to use at login, usually admin")
        var username: String
        @Option(help: "Password to be used at login, i.e. \(randomPassword())")
        var password: String
        @Option(help: "Path to an aliases file, i.e. ~/.gwnaliases.txt")
        var aliases: String?
        @Option(help: "Log level (1..5)")
        var logLevel: UInt = GwnContext.LogLevel.info.rawValue

        /// Generates an 8 character pseudo random password. Just to have a different password in the command line help every time you call it 🤡
        static func randomPassword() -> String {
            return String((0..<8).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        }
    }

    static let configuration = CommandConfiguration(
        // Optional abstracts and discussions are used for help output.
        abstract: "A command-line utility for Grandstream WiFi access points.",
        version: "1.0.0", //  automatic '--version' support.
        subcommands: [ListRules.self, AddOrUpdate.self, DeleteRule.self],
        defaultSubcommand: ListRules.self)
}

// MARK: - List rules

extension Gwncli {

    struct ListRules: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "Lists currently active bandwidth rules."
        )
        
        @OptionGroup var options: CommonOptions

        mutating func run() async throws {
            guard let gwnUrl = URL(string: options.url) else {
                throw GwnError.freeForm("Invalid url \(options.url)")
            }
#if !os(Linux)
            let session = URLSession(configuration: URLSession.shared.configuration, delegate: TlsWarningsIgnoringUrlSessionDelegate(), delegateQueue: nil)
#else
            let session = URLSession(configuration: URLSession.shared.configuration)
#endif
            
            let context = GwnContext(session: session,
                                     url: gwnUrl,
                                     userName: options.username,
                                     password: options.password,
                                     aliases: options.aliases,
                                     logLevel: GwnContext.LogLevel(rawValue: options.logLevel))
            
            do {
                var updatedContext = try await GWN.readAliases(context: context)
                updatedContext = try await GWN.acquireSession(context: updatedContext)
                let configuration = try await GWN.getConfiguration(context: updatedContext)
                print(configuration.bandwidthRulesFormatted(aliases: updatedContext.aliases))
            } catch let error as GwnError {
                throw error
            } catch {
                throw GwnError.networkError(error)
            }
        }
    }
}

// MARK: - Add / update rule

extension Gwncli {

    struct AddOrUpdate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
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

        func run() async throws {
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
            
#if !os(Linux)
            let session = URLSession(configuration: URLSession.shared.configuration, delegate: TlsWarningsIgnoringUrlSessionDelegate(), delegateQueue: nil)
#else
            let session = URLSession(configuration: URLSession.shared.configuration)
#endif
            let context = GwnContext(session: session,
                                     url: gwnUrl,
                                     userName: options.username,
                                     password: options.password,
                                     aliases: options.aliases,
                                     logLevel: GwnContext.LogLevel(rawValue: options.logLevel))
            
            do {
                var updatedContext = try await GWN.readAliases(context: context)
                updatedContext = try await GWN.acquireSession(context: updatedContext)
                let configuration = try await GWN.addOrUpdateRule(context: updatedContext, mac: mac, ssidId: ssid, drate: drate, urate: urate)
                print(configuration.bandwidthRulesFormatted(aliases: updatedContext.aliases))
            } catch let error as GwnError {
                throw error
            } catch {
                throw GwnError.networkError(error)
            }
        }
    }
}

// MARK: - Delete rule

extension Gwncli {
    struct DeleteRule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Removes a bandwidth rule for the given address."
        )
        
        @OptionGroup var options: CommonOptions

        @Option(help: "Name of the rule to delete (use 'list' subcommand to see all rules)")
        var ruleName: String?
        
        @Option(help: "If given, all rules for that mac address will be deleted")
        var mac: String?

        func run() async throws {
            guard let gwnUrl = URL(string: options.url) else {
                throw GwnError.freeForm("Invalid url \(options.url)")
            }
            guard nil != ruleName || nil != mac else {
                throw GwnError.freeForm("You must provide either a rule name or a mac address!")
            }
            
#if !os(Linux)
            let session = URLSession(configuration: URLSession.shared.configuration, delegate: TlsWarningsIgnoringUrlSessionDelegate(), delegateQueue: nil)
#else
            let session = URLSession(configuration: URLSession.shared.configuration)
#endif
            let context = GwnContext(session: session,
                                     url: gwnUrl,
                                     userName: options.username,
                                     password: options.password,
                                     aliases: options.aliases,
                                     logLevel: GwnContext.LogLevel(rawValue: options.logLevel))
            
            do {
                var updatedContext = try await GWN.readAliases(context: context)
                updatedContext = try await GWN.acquireSession(context: updatedContext)
                let configuration = try await GWN.deleteRule(context: updatedContext, ruleName: ruleName, macAddress: mac)
                print(configuration.bandwidthRulesFormatted(aliases: updatedContext.aliases))
            } catch let error as GwnError {
                throw error
            } catch {
                throw GwnError.networkError(error)
            }
        }
    }
}
