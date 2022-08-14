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
                                     password: options.password)
            GWN.acquireSession(context: context)
                .flatMap { GWN.getConfiguration(context: $0) }
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case let .failure(gwnError):
                        ListRules.exit(withError: gwnError)
                    case .finished:
                        ListRules.exit()
                    }
                }, receiveValue: { configuration in
                    print(configuration.bandwidthRulesFormatted)
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
        
        func run() throws {
            
        }
    }
    
    /*
     ==== ADD ====
     
     POST /ubus/uci.add HTTP/1.1
     {"id":35,"jsonrpc":"2.0","method":"call","params":["318597ec028684aae36952d981e9fbbf","uci","add",{"config":"grandstream","values":{"id":"AA:BB:CC:DD:EE:FF","enabled":1,"type":"mac","urate":"11Mbps","drate":"22Kbps","ssid_id":"ssid1"},"type":"bwctrl-rule","name":"rule4"}]}
     
     RESPONSE
     {
         "jsonrpc": "2.0",
         "id": 35,
         "result": [
             0,
             {
                 "section": "rule4"
             }
         ]
     }
     
     GET Config
     [{"id":36,"jsonrpc":"2.0","method":"call","params":["318597ec028684aae36952d981e9fbbf","uci","get",{"config":"grandstream"}]}]
     
     POST /ubus/uci.changes HTTP/1.1
     {"id":37,"jsonrpc":"2.0","method":"call","params":["318597ec028684aae36952d981e9fbbf","uci","changes",{}]}
     
     POST /ubus/uci.apply HTTP/1.1
     {"id":38,"jsonrpc":"2.0","method":"call","params":["318597ec028684aae36952d981e9fbbf","uci","apply",{"timeout":10,"rollback":true}]}
     
     POST /ubus/uci.confirm HTTP/1.1
     {"id":39,"jsonrpc":"2.0","method":"call","params":["318597ec028684aae36952d981e9fbbf","uci","confirm",{}]}
     
     RESPONSE
     {
         "jsonrpc": "2.0",
         "id": 39,
         "result": [
             0
         ]
     }
     
     ==== UPDATE ====
     
     POST /ubus/uci.set HTTP/1.1
     {"id":57,"jsonrpc":"2.0","method":"call","params":["318597ec028684aae36952d981e9fbbf","uci","set",{"config":"grandstream","section":"rule4","values":{"enabled":1,"urate":"33Kbps","drate":"44Mbps"}}]}
     Apply + confirm
     
     */

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
                                     password: options.password)
            GWN.acquireSession(context: context)
                .flatMap { GWN.deleteRule(context: $0, ruleName: ruleName) }
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case let .failure(gwnError):
                        DeleteRule.exit(withError: gwnError)
                    case .finished:
                        DeleteRule.exit()
                    }
                }, receiveValue: { (void: Void) in
                    
                })
                .store(in: &cancellables)
            RunLoop.current.run()
        }
    }
}
