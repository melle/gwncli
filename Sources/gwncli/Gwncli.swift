// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import ArgumentParser
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@main
struct Gwncli: AsyncParsableCommand {
    
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
        @Option(help: "Log level (1..5), default 4 (3 for the throttle-/cleanup-locally-administered subcommands)")
        var logLevel: UInt?

        /// The log level given on the command line, or the given default.
        func logLevel(default defaultLevel: GwnContext.LogLevel) -> GwnContext.LogLevel {
            logLevel.flatMap { GwnContext.LogLevel(rawValue: $0) } ?? defaultLevel
        }

        /// Generates an 8 character pseudo random password. Just to have a different password in the command line help every time you call it 🤡
        static func randomPassword() -> String {
            return String((0..<8).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        }
    }

    /// Parses an age expression like "30m", "12h" or "7d" into seconds.
    static func parseAge(_ age: String) throws -> TimeInterval {
        guard let unit = age.last, let value = Double(age.dropLast()), value >= 0 else {
            throw GwnError.freeForm("Age must be a number followed by m, h or d, i.e. 12h or 7d")
        }
        switch unit {
        case "m": return value * 60
        case "h": return value * 3600
        case "d": return value * 86400
        default: throw GwnError.freeForm("Age must be a number followed by m, h or d, i.e. 12h or 7d")
        }
    }

    /// GWN is very picky about the units, only Mbps and Kbps in the right case are allowed.
    static func validateRates(_ rates: String...) throws {
        guard let regex = try? NSRegularExpression(pattern: "[0-9]*[M,K]bps") else {
            throw GwnError.freeForm("Invalid rate validation pattern")
        }
        for rate in rates {
            guard 1 == regex.numberOfMatches(in: rate, range: NSRange(location: 0, length: rate.utf16.count)) else {
                throw GwnError.freeForm("Upload/Download rate must be expressed as Mbps or Kbps, i.e 64Kbps")
            }
        }
    }

    static let configuration = CommandConfiguration(
        // Optional abstracts and discussions are used for help output.
        abstract: "A command-line utility for Grandstream WiFi access points.",
        version: "1.0.0", //  automatic '--version' support.
        subcommands: [ListRules.self, AddOrUpdate.self, DeleteRule.self, Throttle.self, Cleanup.self],
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
                                     logLevel: options.logLevel(default: .info))

            do {
                let configuration = try await context
                    .readingAliases()
                    .acquiringSession()
                    .fetchingConfiguration()
                
                print(configuration.bandwidthRulesFormatted(aliases: context.aliases))
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
            try Gwncli.validateRates(drate, urate)

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
                                     logLevel: options.logLevel(default: .info))

            do {
                let configuration = try await context
                    .readingAliases()
                    .acquiringSession()
                    .addingOrUpdatingRule(mac: mac, ssidId: ssid, drate: drate, urate: urate)
                
                print(configuration.bandwidthRulesFormatted(aliases: context.aliases))
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
                                     logLevel: options.logLevel(default: .info))

            do {
                let configuration = try await context
                    .readingAliases()
                    .acquiringSession()
                    .deletingRule(ruleName: ruleName, macAddress: mac)

                print(configuration.bandwidthRulesFormatted(aliases: context.aliases))
            } catch let error as GwnError {
                throw error
            } catch {
                throw GwnError.networkError(error)
            }
        }
    }
}

// MARK: - Cleanup rules of vanished randomized MACs

extension Gwncli {
    struct Cleanup: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cleanup-locally-administered",
            abstract: "Deletes bandwidth rules for randomized (locally administered) MAC addresses whose clients are gone.",
            discussion: """
                Counterpart of throttle-locally-administered: deletes rules whose randomized MAC \
                is no longer in the access point's client list, or has been offline for longer \
                than --max-age. MAC addresses listed in the aliases file are never touched, so \
                the aliases file acts as a keep-list for manually maintained rules.

                Intended to be run daily from cron. Prints one line per deleted rule and nothing \
                at all when there is nothing to do.

                Example crontab entry:
                13 4 * * * gwncli cleanup-locally-administered --url https://gwn_c074ad7b2950.local --username admin --password secret --aliases /home/user/.gwnaliases.txt
                """
        )

        @OptionGroup var options: CommonOptions

        @Option(help: "Also delete rules for clients that have been offline for longer than this (m/h/d suffix, i.e. 12h or 7d)")
        var maxAge: String = "7d"
        @Flag(help: "Only print what would be deleted, without changing anything")
        var dryRun: Bool = false

        func run() async throws {
            guard let gwnUrl = URL(string: options.url) else {
                throw GwnError.freeForm("Invalid url \(options.url)")
            }
            let maxAgeSeconds = try Gwncli.parseAge(maxAge)

#if !os(Linux)
            let session = URLSession(configuration: URLSession.shared.configuration, delegate: TlsWarningsIgnoringUrlSessionDelegate(), delegateQueue: nil)
#else
            let session = URLSession(configuration: URLSession.shared.configuration)
#endif
            // On Linux, a URLSession that is deallocated without being invalidated can
            // abort the process at exit - fatal for a cron job that must exit 0 when idle.
            defer { session.finishTasksAndInvalidate() }
            let context = GwnContext(session: session,
                                     url: gwnUrl,
                                     userName: options.username,
                                     password: options.password,
                                     aliases: options.aliases,
                                     logLevel: options.logLevel(default: .warning))

            do {
                let deleted = try await context
                    .readingAliases()
                    .acquiringSession()
                    .cleaningUpRandomizedRules(maxAge: maxAgeSeconds, dryRun: dryRun)

                for candidate in deleted {
                    print("\(dryRun ? "Would delete" : "Deleted") \(candidate.ruleName) for \(candidate.mac) (\(candidate.reason))")
                }
            } catch let error as GwnError {
                throw error
            } catch {
                throw GwnError.networkError(error)
            }
        }
    }
}

// MARK: - Throttle randomized MACs

extension Gwncli {
    struct Throttle: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "throttle-locally-administered",
            abstract: "Adds a bandwidth rule for every WiFi client with a randomized (locally administered) MAC address.",
            discussion: """
                Intended to be run periodically from cron. Prints one line per newly created rule \
                and nothing at all when every randomized MAC is already covered by a rule, so cron \
                stays quiet unless something happened.

                Example crontab entry:
                */5 * * * * gwncli throttle-locally-administered --url https://gwn_c074ad7b2950.local --username admin --password secret
                """
        )

        @OptionGroup var options: CommonOptions

        @Option(help: "Download-Rate applied to new rules (Mbps/Kbps)")
        var drate: String = "32Kbps"
        @Option(help: "Upload-Rate applied to new rules (Mbps/Kbps)")
        var urate: String = "1000Mbps"
        @Option(help: "SSID-id the new rules apply to (i.e. ssid0). Default: resolved from the SSID the client is connected to")
        var ssid: String?
        @Flag(help: "Only print what would be throttled, without changing anything")
        var dryRun: Bool = false

        func run() async throws {
            guard let gwnUrl = URL(string: options.url) else {
                throw GwnError.freeForm("Invalid url \(options.url)")
            }
            try Gwncli.validateRates(drate, urate)

#if !os(Linux)
            let session = URLSession(configuration: URLSession.shared.configuration, delegate: TlsWarningsIgnoringUrlSessionDelegate(), delegateQueue: nil)
#else
            let session = URLSession(configuration: URLSession.shared.configuration)
#endif
            // On Linux, a URLSession that is deallocated without being invalidated can
            // abort the process at exit - fatal for a cron job that must exit 0 when idle.
            defer { session.finishTasksAndInvalidate() }
            let context = GwnContext(session: session,
                                     url: gwnUrl,
                                     userName: options.username,
                                     password: options.password,
                                     aliases: options.aliases,
                                     logLevel: options.logLevel(default: .warning))

            do {
                let throttled = try await context
                    .acquiringSession()
                    .throttlingRandomizedClients(drate: drate, urate: urate, ssidOverride: ssid, dryRun: dryRun)

                for candidate in throttled {
                    let host = candidate.hostname.isEmpty ? "" : " (\(candidate.hostname))"
                    print("\(dryRun ? "Would throttle" : "Throttled") \(candidate.mac)\(host) on \(candidate.ssidId): down \(drate), up \(urate)")
                }
            } catch let error as GwnError {
                throw error
            } catch {
                throw GwnError.networkError(error)
            }
        }
    }
}
