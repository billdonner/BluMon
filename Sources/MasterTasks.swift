//
//  TaskList.swift
//  igbluemon
//
//  Created by bill donner on 3/14/17.
//  Copyright © 2017 billdonner. All rights reserved.
//

import Foundation
import KitCommons
import Dispatch
// shim gives us a class that can be instantiated and run in the background independent of Kitura

 let framesPerSecond = 10.0

 class MTShim {
    
    
   
    
    var cnt = 0
    static let delay = Double(1000.0/framesPerSecond)
    let delayQ = DispatchQueue(label: UUID.init().uuidString)
    let delayT = DispatchTimeInterval.milliseconds( Int(delay))
    
    init() throws {
        try MasterTasks.setup()
        MasterTasks.newTaskList()
    }
    
    func start() {
        delayQ.asyncAfter(deadline:.now() + self.delayT){
            self.cnt += 1
            MasterTasks.runScheduler()
            self.start()
        }
    }
}



typealias ServerInfo = [String:String]

enum DisplayDecorations : Int {
    case reddish
    case yellowish
    case blueish
}

enum TaskSortOrdering: String {
    case status
    case server
    case uptime
    case description
    case name
    case version
}
enum TinyError:Error {
    case infoplist
    case cantSerializeJSON
}
///////////
///////////


/// ItemData is safely copied out to callers  so the task schedule can be private
fileprivate struct ItemData  {
    
    var status: Int
    var server: String
    var name: String
    var uptime: Double
    var description : String
    var version : String
    var inprogress : Bool
    var downcount: Int
    var statusEndpoint: String
    
    var displayDecorations : DisplayDecorations
    
    init(_ td:TaskData){
        self.status = td.status
        self.server = td.server
        self.downcount = td.downcount
        self.name = td.name
        self.uptime = td.uptime
        self.description = td.description
        self.version = td.version
        self.inprogress = td.inprogress
        self.displayDecorations = td.displayDecorations 
        self.statusEndpoint = td.statusEndpoint
        
    }
    
    
    var paddedUptime: String {
        let sup = "\(uptime)"
        let str = sup.components(separatedBy: ".").first!
        if  let xx = Double(str as String) {
            if xx > 0 {
                let paddedStr = str.leftPadding(toLength:7,  withPad: "0" )
                return paddedStr
            }
        }
        
        return "9999999"
    }
}


///////////
///////////
///////////
///////////
///////////

/// each task/row in the class list is a TaskData class instance that is allocated once and updated from all directions

fileprivate class  TaskData {
    
    var status: Int
    var server: String
    
    var statusEndpoint: String
    var name: String
    var uptime: Double
    var description : String
    var version : String
    var inprogress = false
    var downcount: Int
    var secsBetweenBadPolls: TimeInterval = 120
    var secsBetweenGoodPolls: TimeInterval = 10
    var selfidx: Int
    //var lastResponse:[[String:Any]]
    var displayDecorations : DisplayDecorations
    var  session  =  { () -> URLSession in
        let urlconfig = URLSessionConfiguration.default
        urlconfig.timeoutIntervalForRequest = 15
        urlconfig.timeoutIntervalForResource = 15
        return  URLSession(configuration: urlconfig, delegate: nil, delegateQueue: nil)
    }()
    
    init(idx: Int, status: Int, name: String, server: String, statusEndpoint: String,
         uptime: Double, description: String, version:String,
         downcount: Int, ish: DisplayDecorations, last:[[String:Any]]) {
        
        self.selfidx = idx
        self.status = status
        self.name = name
        self.server = server
        self.statusEndpoint = statusEndpoint
        self.uptime = uptime
        self.version = version
        self.description = description
        self.displayDecorations  = ish
       // self.lastResponse = last
        self.downcount = downcount
    }
    func htmlForRow() -> String {
        let prettyup = String(format:"%0.2f",uptime)
        return  "<tr><td>\(selfidx)</td><td>\(status)</td><td>\(name)</td><td><a href='\(server)'>\(server)</a></td><td>\(downcount)</td><td>\(prettyup)</td><td>\(version)</td></tr>"
        
    }
    static func tableHeader() -> String {
        
        return "<tr><th>idx</th><th>status</th><th>name</th><th>server</th><th>down</th><th>uptime</th><th>version</th></tr>"
    }
    func dictFor() -> [String:Any]{
        return [
            "selfidx": selfidx,
            "status": status,
            "servertitle": name,
            "server": server,
            "statusEndpoint": statusEndpoint,
            "softwareversion": version,
            "up-time": uptime,
            "description": description,
            // "displayDecorations": displayDecorations,
            //"lastResponse": lastResponse,
            "downcount": downcount]
    }
    var debugDescription: String {
        return  "\(uptime) " + "\(server)" + " status: \(status)"
    }
}


///////////
///////////


/// the TL is the tasklist, one row per TaskData element
///  it is completely static, essentially a fancy global

public struct MasterTasks {
 
    fileprivate static let startdate = Date()
    
    static var masterDict: [String:Any]  {
        var out:[[String:Any]] = []
        for row in taskRows {
            let tr = row.dictFor()
            out.append(tr)
        }
        let final :  [String:Any] = ["master":out]
        return final
        
    }

    fileprivate static var taskRows: [TaskData] = []
    fileprivate static var info : [String:Any] = [:] //maps url to taskRows indicies
    fileprivate static var dateFormate = DateFormatter()
    
    static func nicedate() -> String {
        MasterTasks.dateFormate.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return MasterTasks.dateFormate.string(from: Date())
    }
    static func htmlDynamicPageDisplay(baseurl:String)   -> String  {
        let p1 = "BlueMon on BlueMix"
        let p2 = "SocialMaxx Server Empire"
        let p3 = "for (m)admen only"
        
        let p4 = MasterTasks.nicedate()
        let p5 = "&copy; Copyright SocialMaxx 2017. Built on open-source IBM Kitura and Swift"
        let p6 = "docs->"
        let link1 = "https://github.com/billdonner"
        let img1 = "http://billdonner.com/tr/computerUser.gif"
        let icon1 = baseurl + "/fs/kitura-bird.svg"
        let cssurl = baseurl + "/fs/welcome.css"
        let img2 =   "http://billdonner.com/tr/sample-shot.png"////baseurl + "/fs/sample-shot.png"
        
        var html = "<!DOCTYPE html> <html> <head> <meta http-equiv='refresh' content='2'><title>Blue Servers Monitor </title>" +
            "<link rel='stylesheet' href='\(cssurl)' /> </head> <body>  <div class='titleBar'>" +
            "<img src='\(icon1)' class='titleIcon'/> <div class='titleSeparator'></div>" +
            "<h1 class='titleText'>\(p1)</h1></div><div class='documentContents'><div align='center' style='margin-top: 26px;'><img src='\(img1)' height='118px' width='165px'/></div>" +
            "<div class='welcomeText' align='center'>\(p2)</div><div class='contentCenterSpacer'></div><div class='statusText' align='center'>" +
            "\(p3)</div>" +
            "<div align='center' style='margin-top: 28px;'><div class='contentCenter' align='center'><div class='contentLeading' align='center'>" +
        " <img src='\(img2)' height='40px'  /></div><div class='version' align='center'><table>"
        
        
        html += TaskData.tableHeader()
        for task in taskRows {
            let inner = task.htmlForRow()
            html += inner
        }
        html += "</table></div>  <div class='todText' align='right'>\(p4)</div></div></div>" +
            "<div class='footerBar'>   <div class='footerText' style='margin-left: 40px;'>\(p5)" +
            "</div><a class='footerSwift' href='\(link1)'>\(p6)</a></div>" +
        "</div></body></html>"
        return html
    }
    
    
    fileprivate static func jsonData() throws -> Data {
        let dict = masterDict
        if let json = try? JSONSerialization.data(withJSONObject: dict,options: .prettyPrinted) {
            return json
        }
        throw TinyError.cantSerializeJSON
    }
    
    public static func setup() throws{
        let bc =   BlueConfig()
        try bc.process( configurl: nil)
        // print(bc.grandConfig)
        //print(bc.localConfig)
        if  let bt = bc.grandConfig["servers"] as? [ServerInfo] {
            MasterTasks.make(bt)
        }
    }
    
    public static  func runScheduler() {
        // counts down each task and starts remote api call whenever apvarpriate
        let theRows = taskRows // copy so it can mutate
        // print ("runSched entrance with sss \(sss)")
        var theIndex = 0
        for task in theRows  { // each on list
            
            let dorun = countDown(idx: theIndex)
            let inprog = task.inprogress   // skip if busy
            
            //print("runSched countdown \ {(dorun) inprog \(inprog) for poll \(task.server)")
            
            if dorun && !inprog {
                task.displayDecorations = .yellowish
                
                // print("runSched will poll \(task.server) idx \(MasterTasks.idx(url:task.server))")
                remoteHTTPCall(task.statusEndpoint,baseurl: task.server ) { apistatus, status, name,uptime,description,version, server, response  in
                    
                    
                    if let merow = idx(url: server) {
                        
                        if apistatus == 200 && status ==  200   {
                            
                            let td =  taskRows[merow ]
                            td.status = apistatus
                            td.name = name
                            td.description = description
                            td.version = version
                            td.server = server
                            td.uptime = uptime
                            td.displayDecorations = .blueish
                            //td.lastResponse = response
                            
                        } else {
                            // in case of error copy fordward much of the exisating taskdata
                            //let td = MasterTasks.taskList.taskRows[merow ]
                            
                            let td =  taskRows[merow ]
                            td.status =  status
                            td.displayDecorations = .reddish
                            td.downcount = Int(td.secsBetweenBadPolls * framesPerSecond)// wait a minute after bad response
                        }
                    }
                }//remoteHTTPCall
            }// not in progress
            theIndex += 1
        }// for loop
    }// run scheduler
    
    //TODO: fix sorting
  //  static func reloadTaskList(ordering:TaskSortOrdering,ascending:Bool) {
//        //   taskRows = contentsOrderedBy(ordering, ascending: ascending)
//    }
   public  static func newTaskList() {
        // MasterTasks.taskList = TaskList()
    }
   fileprivate static func itemData(row:Int) -> ItemData {
        return ItemData(taskRows[row])
    }
    fileprivate    static func tasksCount()->Int {
        return taskRows.count
    }
    
    fileprivate    static func idx(url:String) -> Int? {
        if let  t = info[url] as?   Int {
            return t
        }
        return nil
    }
    
    //countdown and reset for this entry
    fileprivate    static func countDown(idx:Int) -> Bool {
        
        let td = taskRows[idx]
        td.downcount -= 1
        if td.downcount <= 0 {
            td.downcount   = Int(td.secsBetweenGoodPolls * framesPerSecond)
            return true
        }
        return false
    }
    
    fileprivate   static func make(_ x:[ServerInfo]) {
        var idx = 0
        info = [:]
        for each in x {
            if let comment = each["comment"] {
                print ("comment:\(comment)")
            }
            if let bb = each["server"], let cc = each["status-url"] {
                info[bb] = idx
                // start each a litttle later by setting the downcount differently
                taskRows.append(TaskData(idx: idx, status:  100 ,
                                         name:bb, server: bb, statusEndpoint:cc , uptime: 0, description: "", version:"",
                                         downcount: idx, ish:.reddish,last:[]))
            }
            idx += 1
        } // for
    }
    
    fileprivate   static  func contentsOrderedBy(_ orderedBy: TaskSortOrdering, ascending: Bool) -> [TaskData] {
        let sortedFiles: [TaskData]
        switch orderedBy {
        case .status:
            sortedFiles = taskRows.sorted {
                return sortNestedData(lhsIsFolder:true, rhsIsFolder: true, ascending: ascending,
                                    attributeComparation:itemComparator(lhs:$0.status, rhs: $1.status, ascending:ascending))
            }
        case .server:
            sortedFiles = taskRows.sorted {
                return sortNestedData(lhsIsFolder:true, rhsIsFolder: true, ascending:ascending,
                                    attributeComparation:itemComparator(lhs:$0.server, rhs: $1.server, ascending: ascending))
            }
        case .uptime:
            sortedFiles =  taskRows.sorted {
                return sortNestedData(lhsIsFolder:true, rhsIsFolder: true, ascending:ascending,
                                    attributeComparation:itemComparator(lhs:$0.uptime, rhs: $1.uptime, ascending:ascending))
            }
        case .description:
            sortedFiles =  taskRows.sorted {
                return sortNestedData(lhsIsFolder:true, rhsIsFolder: true, ascending:ascending,
                                    attributeComparation:itemComparator(lhs:$0.description, rhs: $1.description, ascending:ascending))
            }
        case .version:
            sortedFiles =  taskRows.sorted {
                return sortNestedData(lhsIsFolder:true, rhsIsFolder: true, ascending:ascending,
                                    attributeComparation:itemComparator(lhs:$0.version, rhs: $1.version, ascending:ascending))
            }
        case .name:
            sortedFiles =  taskRows.sorted {
                return sortNestedData(lhsIsFolder:true, rhsIsFolder: true, ascending:ascending,
                                    attributeComparation:itemComparator(lhs:$0.name, rhs: $1.name, ascending:ascending))
            }
        }
        return sortedFiles
    }
    
    // make a remoteurl call
    // - the baseurl is used only as a key to obtain the index in the taskrows table
    
    fileprivate   static func remoteHTTPCall(_ remoteurl: String,  baseurl: String,
                                             completion:@escaping (Int, Int,String,Double,String,String,String,[[String:Any]])->())
    {
        guard let idx = info[baseurl] as?  Int else { return }
        let t =  taskRows[idx]
        guard !t.inprogress else { return }
  
        let url  = URL(string: remoteurl)!
        let request = URLRequest(url: url)

        t.inprogress = true
        // now using a session per datatask so it hopefully runs better under linux
        
        //fatal error: Transfer completed, but there's no currect request.: file Foundation/NSURLSession/NSURLSessionTask.swift, line 794
        
        //https://github.com/stormpath/Turnstile/issues/31

        let task = t.session.dataTask(with: request) {data,response,error in
            t.inprogress = false
            
            if let httpResponse = response as? HTTPURLResponse  {
                let code = httpResponse.statusCode
                guard code == 200 else {
                    print("remoteHTTPCall to \(url) completing with error \(code)")
                    completion(code, code ,"",0,"","",baseurl,[]) //fix
                    return
                }
            }
            guard error == nil  else {
                print("remoteHTTPCall to \(url) completing without code error \(error)")
                completion(529,  529 ,"",0,"","",baseurl,[]) //fix
                return
            }
            /// parse what we got
            guard let data = data,
                let eee = try? JSONSerialization.jsonObject(with:data, options: .allowFragments)
                as? [String: Any],
                let d = eee,
                let t = d ["servertitle"] as? String ,
                let p = d ["description"] as? String ,
                let v =  d["softwareversion"] as? String
            else {
                    //bad parse
                    completion(527,527,"",0,"","",baseurl,[]) //fix
                    print("remoteHTTPCall to \(baseurl) could not parse remote response")
                    return
            }
            let r =  200
                    var ddd:TimeInterval = 0.0
                    if let dd = d["up-time"] as? Double {
                        ddd = dd
                    } else 
                     if let ss = d ["elapsed-secs"] as? String {
                            ddd =  Double(ss)!
                        }
                  if  let dict = d ["master"] as? [[String:Any]]{
                        completion(200, r,t,ddd,p,v,baseurl,dict)
                    }
                    else {
                        completion(541, r,t,ddd,p,v,baseurl,[])
                    }
                    return
                } // good parse
        task.resume()
    }
}//extension

// MARK:  TaskData  Equatable

fileprivate func ==(lhs: TaskData, rhs: TaskData) -> Bool {
    return (lhs.server == rhs.server)
}
