/*
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Kitura
import LoggerAPI
import HeliumLogger
import SwiftKuery
import SwiftKueryPostgreSQL
import KituraStencil
import Stencil

Log.logger = HeliumLogger(.info)

// Stencil stuff
let ext = Extension()

// Stencil does not yet support automatic HTML escaping:
// https://github.com/kylef/Stencil/pull/80
//
ext.registerFilter("htmlencode") { (value: Any?) in
    if let value = value as? String {
        return value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
    return value
}

let router = Router()
router.add(templateEngine: StencilTemplateEngine(extension: ext))

//
// TechEmpower test 6: plaintext
//
router.get("/plaintext") {
    request, response, next in
    response.headers["Server"] = "Kitura"
    response.headers["Content-Type"] = "text/plain"
    try response.status(.OK).send("Hello, world!").end()
}

//
// TechEmpower test 1: JSON serialization
//
router.get("/json") {
    request, response, next in
    response.headers["Server"] = "Kitura"
    let result = ["message":"Hello, World!"]
    try response.status(.OK).send(json: result).end()
}

//
// TechEmpower test 2: Single database query (raw, no ORM)
//
router.get("/db") {
    request, response, next in
    response.headers["Server"] = "Kitura"
    let result = getRandomRow()
    guard let dict = result.0 else {
        guard let err = result.1 else {
            Log.error("Unknown Error")
            try response.status(.badRequest).send("Unknown error").end()
            return
        }
        Log.error("\(err)")
        try response.status(.badRequest).send("Error: \(err)").end()
        return
    }
    try response.status(.OK).send(json: dict).end()
}

//
// TechEmpower test 3: Multiple database queries (raw, no ORM)
// Get param provides number of queries: /queries?queries=N
//
router.get("/queries") {
    request, response, next in
    response.headers["Server"] = "Kitura"
    let queriesParam = request.queryParameters["queries"] ?? "1"
    let numQueries = max(1, min(Int(queriesParam) ?? 1, 500))      // Snap to range of 1-500 as per test spec
    var results: [[String:Int]] = []
    for _ in 1...numQueries {
        let result = getRandomRow()
        guard let dict = result.0 else {
            guard let err = result.1 else {
                Log.error("Unknown Error")
                try response.status(.badRequest).send("Unknown error").end()
                return
            }
            Log.error("\(err)")
            try response.status(.badRequest).send("Error: \(err)").end()
            return
        }
        results.append(dict)
    }
    // Return JSON representation of array of results
    try response.status(.OK).send(json: results).end()
}

//
// TechEmpower test 4: fortunes (raw, no ORM)
//
router.get("/fortunes") {
    request, response, next in
    response.headers["Server"] = "Kitura"
    response.headers["Content-Type"] = "text/html; charset=UTF-8"
    let result = getFortunes()
    guard var fortunes = result.0 else {
        guard let err = result.1 else {
            Log.error("Unknown Error")
            try response.status(.badRequest).send("Unknown error").end()
            return
        }
        Log.error("\(err)")
        try response.status(.badRequest).send("Error: \(err)").end()
        return
    }
    fortunes.append(Fortune(id: 0, message: "Additional fortune added at request time."))
    do {
      try response.render("fortunes.stencil", context: ["fortunes": fortunes.sorted()]).end()
    } catch {
      print("Error: \(error)")
    }
}

//
// TechEmpower test 5: updates (raw, no ORM)
//
router.get("/updates") {
    request, response, next in
    response.headers["Server"] = "Kitura"
    let queriesParam = request.queryParameters["queries"] ?? "1"
    let numQueries = max(1, min(Int(queriesParam) ?? 1, 500))      // Snap to range of 1-500 as per test spec
    var results: [[String:Int]] = []
    for _ in 1...numQueries {
        let result = getRandomRow()
        guard let dict = result.0 else {
            guard let err = result.1 else {
                Log.error("Unknown Error")
                try response.status(.badRequest).send("Unknown error").end()
                return
            }
            Log.error("\(err)")
            try response.status(.badRequest).send("Error: \(err)").end()
            return
        }
        do {
            var error: AppError?
            try error = updateRow(id: dict["id"]!)
            if let appError = error {
                throw appError
            }
        } catch let err as AppError {
            try response.status(.badRequest).send("Error: \(err)").end()
            return
        }
        results.append(dict)
    }
    
    // Return JSON representation of array of results
    try response.status(.OK).send(json: results).end()
}


Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()
