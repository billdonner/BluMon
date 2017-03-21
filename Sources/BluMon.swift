struct BluMon {

    var text = "Hello, World from BluMon!"
}
import Foundation
import Kitura
import SwiftyJSON
import LoggerAPI
import Configuration
import CloudFoundryEnv
import CloudFoundryConfig
import CloudFoundryDeploymentTracker
import KitCommons

//touch
let serverConfigBluMon =
    ServerConfig( version: "0.998923",
                  title: "BLUMON",
                  description: "monitor igblue server performance",
                  ident : "https://igblue.mybluemix.net")

extension   StandardController {
    public convenience init() throws {
        try self.init(serverConfigBluMon)
        CloudFoundryDeploymentTracker(repositoryURL: "https://github.com/IBM-Bluemix/Kitura-Starter.git", codeVersion: nil).track()
        
    }
    
    open func start() throws {
        let s = Kitura.addHTTPServer(onPort:  port, with:  router)
        s.started {
            // wait for Kitura to get the server going
            
        }
        // Start Kitura-Starter server
        Kitura.run()
    }
    
    open func setupBasicRoutes(router:Router) {
        /// offer public files here - it is used internally to load files at startup as well
        // Basic GET request
        router.get("/", handler: getTopLevel)
        // JSON Get request
        router.get("/json", handler: getJSON)
        
    }
    
    /**
     * Handler for getting an application/json response.
     */
    func getJSON(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        
        global.apic.getIn += 1
        
        if self.jsonEndpointEnabled {
            
            sleep(self.jsonEndpointDelay)
        } else {
            next()
        }
        let payload =  MasterTasks.masterDict
        try finishJSONStatusResponse(payload, request: request, response: response, next: next)
    }
    /**
     * Handler for getting a text/plain response.
     */
    
    
    func getTopLevel(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        global.apic.getIn += 1
        response.headers["Content-Type"] = "text/html; charset=utf-8"
        try response.status(.OK).send(MasterTasks.htmlDynamicPageDisplay(baseurl:url)).end()
    }

}
