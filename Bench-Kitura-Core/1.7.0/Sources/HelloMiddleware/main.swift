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
import Foundation
import Kitura
import KituraSession
import KituraCompression
import LoggerAPI
import HeliumLogger

Log.logger = HeliumLogger(.info)

let router = Router()

router.get("/plaintext") {
request, response, next in
    response.headers["Content-Type"] = "text/plain"
    response.status(.OK).send("Hello, world!")
    //try response.end()
    next()
}

router.all("/", middleware: StaticFileServer())
router.all("/", middleware: StaticFileServer(path: "./public"))
router.all(middleware: BodyParser())
let session = Session(secret: "YOU_SHOULD_ENTER_SOME_SECRET_HERE")
router.all(middleware: session)
router.all(middleware: Compression())

Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()
