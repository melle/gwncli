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
    
    struct ListRules: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "Lists currently active bandwith rules."
        )
        @OptionGroup var options: CommonOptions

        mutating func run() throws {
            guard let gwnUrl = URL(string: options.url) else {
                throw GwnError.freeForm("Invalid url \(options.url)")
            }
            
            let session = URLSession(configuration: URLSession.shared.configuration,
                                     delegate: TlsWarningsIgnoringUrlSessionDelegate(),
                                     delegateQueue: nil)
            
            let canellable = GWN.acquireSession(url: gwnUrl,
                                                user: options.username,
                                                password: options.password,
                                                session: session)
                .flatMap({ token in
                    GWN.getConfiguration(url: gwnUrl, session: session, token: token)
                })
                .sink(receiveCompletion: { completion in
                    ListRules.exit()
                }, receiveValue: { value in
                    print(value.values.values)
                })
            
            
            RunLoop.current.run()
        }
    }
    
    struct AddOrUpdate: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Adds or updates a bandwith rule for the given address."
        )

        @OptionGroup var options: CommonOptions
        
        func run() throws {
            
        }
    }

    struct DeleteRule: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Removed a bandwith rule for the given address."
        )
        
        @OptionGroup var options: CommonOptions
        
        func run() throws {
            
        }
    }
}
//
//let options = Gwncli.parseOrExit()
//
//print("foo")
