import GoogleAPIClientForREST
import GoogleSignIn
import UIKit

class ViewController: UIViewController, GIDSignInDelegate, GIDSignInUIDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UITableViewDataSource {
    
    
    // If modifying these scopes, delete your previously saved credentials by
    // resetting the iOS simulator or uninstall the app.
    private let scopes = [kGTLRAuthScopeCalendarReadonly]
    @IBOutlet private var bottomConstraint: NSLayoutConstraint!
    @IBOutlet private var attendeesContstraint: NSLayoutConstraint!
    @IBOutlet private var pickerView: UIPickerView!
    @IBOutlet private var meetingNameLabel: UILabel!
    @IBOutlet private var timeLeftLabel: UILabel!
    @IBOutlet private var tableView: UITableView!
    
    private let service = GTLRCalendarService()
    private var calendars: [GTLRCalendar_CalendarListEntry]!
    private var events: [GTLRCalendar_Event]!
    let signInButton = GIDSignInButton()
    let output = UITextView()
    let formatter = DateComponentsFormatter()
    var event: GTLRCalendar_Event!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure Google Sign-in.
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = scopes
        GIDSignIn.sharedInstance().signInSilently()
        
        // Add the sign-in button.
        view.addSubview(signInButton)
        
        // Add a UITextView to display output.
        output.frame = CGRect(x: 0, y: 0, width: 300, height: 600)
        output.isEditable = false
        output.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        output.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        output.isHidden = true
        view.addSubview(output);
        
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) {_ in
            
            if let events = self.events {
                let df = DateFormatter()
                df.dateFormat = "hh:mm"
                for event in events {
                    guard let startDate = event.start?.dateTime?.date, let endDate = event.end?.dateTime?.date else {
                        self.meetingNameLabel.text = "no events"
                        self.timeLeftLabel.text = "xD"
                        break
                    }
                    if Date().compare(startDate) == ComparisonResult.orderedDescending &&
                       Date().compare(endDate) == ComparisonResult.orderedAscending {
                        if event != self.event {
                            self.event = event
                            self.tableView.reloadData() 
                        }
                        
                        let timeLeft = event.end!.dateTime!.date.timeIntervalSince(Date())
                        self.formatter.unitsStyle = .positional
                        self.formatter.allowedUnits = [.hour, .minute, .second ]
                        self.formatter.zeroFormattingBehavior = [ .pad ]
                        self.meetingNameLabel.text = event.summary
                        self.timeLeftLabel.text = self.formatter.string(from: timeLeft)
                        break
                    }
                    if Date().compare(startDate) == ComparisonResult.orderedAscending &&
                        Date().compare(endDate) == ComparisonResult.orderedAscending {
                        if event != self.event {
                            self.event = event
                            self.tableView.reloadData()
                        }
                        let timeToNextMeeting = event.start!.dateTime!.date.timeIntervalSince(Date())
                        self.formatter.unitsStyle = .positional
                        self.formatter.allowedUnits = [.hour, .minute, .second ]
                        self.formatter.zeroFormattingBehavior = [ .pad ]
                        self.meetingNameLabel.text = "next: \(event.summary!)"
                        self.timeLeftLabel.text = self.formatter.string(from: timeToNextMeeting)
                        break
                    }
                    
                }
            }
            
        }
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
              withError error: Error!) {
        if let error = error {
            showAlert(title: "Authentication Error", message: error.localizedDescription)
            self.service.authorizer = nil
        } else {
            self.signInButton.isHidden = true
            self.output.isHidden = true
            self.service.authorizer = user.authentication.fetcherAuthorizer()
            fetchEvents()
        }
    }
    
    // Construct a query and get a list of upcoming events from the user calendar
    func fetchEvents() {
        //        let smth = GTLRCalendar_CalendarList.
        //        print("Items, \(smth.items)")
        let query = GTLRCalendarQuery_CalendarListList.query()
        //        let query = GTLRCalendarQuery_CalendarListGet.query(withCalendarId: <#T##String#>)
        
        //        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: "primary")
        //        query.maxResults = 10
        //        query.timeMin = GTLRDateTime(date: Date())
        //        query.singleEvents = true
        //        query.orderBy = kGTLRCalendarOrderByStartTime
        service.executeQuery(
            query,
            delegate: self,
            didFinish: #selector(displayResultWithTicket(ticket:finishedWithObject:error:)))
    }
    
    // Display the start dates and event summaries in the UITextView
    func displayResultWithTicket(
        ticket: GTLRServiceTicket,
        finishedWithObject response : GTLRCalendar_CalendarList,
        error : NSError?) {
        
        if let error = error {
            showAlert(title: "Error", message: error.localizedDescription)
            return
        }
        
        calendars = response.items
        //        let cal = response.summary
        if let some = response.items {
            for som in some {
                print("id = \(som.identifier)")
                print("summ = \(som.summary)")
                print("des = \(som.descriptionProperty)")
            }
        }
        pickerView.reloadAllComponents()
        tableView.reloadData()
        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: response.items![0].identifier!)
        query.maxResults = 20
        query.timeMin = GTLRDateTime(date: Date())
        query.singleEvents = true
        query.orderBy = kGTLRCalendarOrderByStartTime
        service.executeQuery(
            query,
            delegate: self,
            didFinish: #selector(events(ticket:finishedWithObject:error:)))
    }
    
    func events(
        
        ticket: GTLRServiceTicket,
        finishedWithObject response : GTLRCalendar_Events,
        error : NSError?) {
        
        var outputText = ""
        events = response.items
        if let events = response.items, !events.isEmpty {
            for event in events {
                let start = event.start!.dateTime ?? event.start!.date!
                let startString = DateFormatter.localizedString(
                    from: start.date,
                    dateStyle: .short,
                    timeStyle: .short)
                outputText += "\(startString) - \(event.summary!)\n"
            }
        } else {
            outputText = "No upcoming events found."
        }
        output.text = outputText
    }
    
    // Helper for showing an alert
    func showAlert(title : String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.alert
        )
        let ok = UIAlertAction(
            title: "OK",
            style: UIAlertActionStyle.default,
            handler: nil
        )
        alert.addAction(ok)
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func showAttendees() {
        self.attendeesContstraint.isActive = !self.attendeesContstraint.isActive
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    @IBAction func refresh() {
        let selectedCal = calendars[pickerView.selectedRow(inComponent: 0)]
        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: selectedCal.identifier!)
        query.maxResults = 20
        query.timeMin = GTLRDateTime(date: Date())
        query.singleEvents = true
        query.orderBy = kGTLRCalendarOrderByStartTime
        service.executeQuery(
            query,
            delegate: self,
            didFinish: #selector(events(ticket:finishedWithObject:error:)))

    }
    
    @IBAction func calButtonTapped() {
        bottomConstraint.isActive = false
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    @IBAction func calSelected() {
        bottomConstraint.isActive = true
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
        let selectedCal = calendars[pickerView.selectedRow(inComponent: 0)]
        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: selectedCal.identifier!)
        query.maxResults = 20
        query.timeMin = GTLRDateTime(date: Date())
        query.singleEvents = true
        query.orderBy = kGTLRCalendarOrderByStartTime
        service.executeQuery(
            query,
            delegate: self,
            didFinish: #selector(events(ticket:finishedWithObject:error:)))
        
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if let calendars = calendars {
            return calendars.count
        } else {
            return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
            let calendar = calendars[row]
            return calendar.summary
        
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let attendees = event?.attendees {
            return attendees.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AtendeeCell") as! AtendeeCell
        let user = event.attendees![indexPath.row].displayName != nil ? event.attendees![indexPath.row].displayName : event.attendees![indexPath.row].email
        cell.userLabel.text = user
        cell.statusLabel.text = event.attendees![indexPath.row].responseStatus

        return cell
    }
}
