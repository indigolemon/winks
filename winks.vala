/*
* winks.vala - Lightweight Browser
*
* Copyright (C) 2010 Graham Thomson <graham.thomson@gmail.com>
* Released under the GNU General Public License (GPL) version 2.
* See COPYING
*/

using Gtk;
using GLib;
using WebKit;
using Soup;

public class winks: Window {
	// constants
	private const string TITLE = "winks";
	private const string HOME_URL = "http://www.google.co.uk/";
	private const string DEFAULT_PROTOCOL = "http";
	private const string VERSION_STRING = "Winks 0.01";

	// regex required
	private Regex protocol_regex;
	private Regex search_check_regex;

	// variables used globally
	private int zoom_level;
	private Session my_session;
	private CookieJarText http_cookies;
	private Entry url_bar;
	private WebView web_view;
	private WebSettings web_settings;
	private Label status_bar;
	private ScrolledWindow scrolled_window;

	// constructor
	public winks () {
		this.title = winks.TITLE;
		set_default_size (1024, 768);

		// Setup required Regex objects
		try {
			this.protocol_regex = new Regex (".*://.*");
			this.search_check_regex = new Regex (".*[.].*");
		} catch (RegexError e) {
			critical ("%s", e.message);
		}

		// Load icon for Application
		try {
			var icon_file = File.new_for_path (Environment.get_home_dir ()+"/.config/winks/winks.png");
			var config_dir = File.new_for_path (Environment.get_home_dir ()+"/.config/winks");
			if (!config_dir.query_exists ()) {
				try{
					config_dir.make_directory_with_parents(null);
					var web_icon = File.new_for_uri ("https://github.com/indigolemon/winks/raw/master/winks.png");
					web_icon.copy (icon_file, FileCopyFlags.NONE);
				} catch (Error e) {
					stderr.printf ("Could not create config dir: %s\n", e.message);
				}
			}
			this.icon = new Gdk.Pixbuf.from_file (icon_file.get_path ());
		} catch (Error e) {
			stderr.printf ("Could not load application icon: %s\n", e.message);
		}

		// Load/Create storage for cookies
		var cookie_file = File.new_for_path (Environment.get_home_dir ()+"/.config/winks/cookies.txt");
		if (!cookie_file.query_exists ()) {
			try {
				cookie_file.create (FileCreateFlags.NONE);
			} catch (Error e) {
				stderr.printf ("Could not create cookie jar: %s\n", e.message);
			}
		}
		this.http_cookies = new CookieJarText (cookie_file.get_path (), false);

		create_widgets ();
		connect_signals ();

		// Session stuff (required for cookies)
		this.my_session = get_default_session ();
		this.http_cookies.attach (this.my_session);

		// zoom indicator
		this.zoom_level = 0;
		// zoom type
		this.web_view.set_full_content_zoom (true);

		// move focus onto the url bar
		this.url_bar.grab_focus ();
	}

	// draw what we need
	private void create_widgets () {
		this.url_bar = new Entry ();
		this.web_settings = new WebSettings ();
		this.web_settings.enable_page_cache = true;
		this.web_settings.user_agent = (this.web_settings.user_agent+" "+VERSION_STRING.replace(" ", "/"));
		this.web_view = new WebView ();
		this.web_view.set_settings (this.web_settings);
		this.scrolled_window = new ScrolledWindow (null, null);
		this.scrolled_window.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		this.scrolled_window.add (this.web_view);
		this.status_bar = new Label ("Welcome to "+VERSION_STRING);
		this.status_bar.xalign = 1;
		this.status_bar.xpad = 5;
		this.status_bar.set_single_line_mode (true);
		var top_bar = new HBox (true, 0);
		top_bar.add (this.url_bar);
		top_bar.add (this.status_bar);
		var main_area = new VBox (false, 0);
		main_area.pack_start (top_bar, false, true, 0);
		main_area.add (this.scrolled_window);
		add (main_area);
	}

	// deal with signals
	private void connect_signals () {
		this.destroy.connect (Gtk.main_quit);
		this.url_bar.activate.connect (on_activate);
		this.web_view.title_changed.connect ((source, frame, title) => {
			this.title = "%s - %s".printf (title, winks.TITLE);
		});
		this.web_view.load_committed.connect ((source, frame) => {
			this.url_bar.text = frame.get_uri ();
		});
		this.web_view.new_window_policy_decision_requested.connect (
			(source, frame, request, action, decision) => {
				this.status_bar.set_text ("Opening New Window | "+VERSION_STRING);
				try {
					GLib.Process.spawn_command_line_async ("winks "+request.get_uri ());
				} catch (GLib.SpawnError e) {
					stderr.printf ("Could not spawn new process: %s\n", e.message);
				}
				return true;
			}
		);
		this.web_view.navigation_policy_decision_requested.connect (
			(source, frame, request, action, decision) => {
				// Find out if we have a cookie for this request
				string found_cookie = this.http_cookies.get_cookies(request.message.get_uri(), true);
				if (found_cookie != null) {
					print ("Found Cookie: %s\n", found_cookie);
					request.message.request_headers.append("Cookie", found_cookie);
				} else {
					print ("No Cookie for: %s\n", request.get_uri ());
				}
				// return true
				decision.use ();
				return true;
			}	
		);
		this.web_view.load_started.connect ((source, frame) => {
			this.url_bar.set_progress_fraction (0.0);
		});
		this.web_view.load_progress_changed.connect ((source, progress) => {
			string the_progress = ("0."+progress.to_string ()).substring(0,3);
			this.url_bar.set_progress_fraction (the_progress.to_double ());
		});
		this.web_view.load_finished.connect ((source, frame) => {
			this.url_bar.set_progress_fraction (0.0);
		});
		this.scrolled_window.set_events(Gdk.EventMask.KEY_PRESS_MASK);
		this.scrolled_window.key_press_event.connect(ProcessKeyPress);
	}

	// process key presses
	private bool ProcessKeyPress( Gdk.EventKey KeyPressed ) {
		string performed_action = "";
		switch (KeyPressed.str.up ()) {
			case "R":
				this.web_view.reload ();
				performed_action = "Page reloaded";
			break;

			case "B":
				if (this.web_view.can_go_back ()){
					this.web_view.go_back ();
					performed_action = "Gone Back 1 Page";
				}
			break;

			case "F":
				if (this.web_view.can_go_forward ()){
					this.web_view.go_forward ();
					performed_action = "Gone Forward 1 Page";
				}
			break;

			case "H":
				this.web_view.open (winks.HOME_URL);
				performed_action = "Homepage Loaded";
			break;

			case "U":
				this.url_bar.grab_focus ();
				performed_action = "Edit URL and hit Enter";
			break;

			case "I":
				this.url_bar.text = "";
				this.url_bar.grab_focus ();
				performed_action = "Type Command/URL and hit Enter";
			break;
			
			case "A":
				this.web_view.zoom_in ();
				this.zoom_level = (this.zoom_level + 1);
				performed_action = "Zoomed In (Level: "+this.zoom_level.to_string ()+")";
			break;
			
			case "Z":
				this.web_view.zoom_out ();
				this.zoom_level = (this.zoom_level - 1);
				performed_action = "Zoomed Out (Level: "+this.zoom_level.to_string ()+")";
			break;
		}
		if (performed_action.length > 0)
			this.status_bar.set_text (performed_action+" | "+VERSION_STRING);
		return true;
	}

	// load a url using soup
	private void load_url (string url) {
		// try some session stuff here
		var message = new Soup.Message ("GET", url);
		// Find out if we have a cookie for this request
		string found_cookie = this.http_cookies.get_cookies(message.get_uri(), true);
		if (found_cookie != null) {
			print ("Found Cookie: %s\n", found_cookie);
			message.request_headers.append("Cookie", found_cookie);
		} else {
			print ("No Cookie for: %s\n", url);
		}
		this.my_session.send_message (message);

		// now open the url
		this.web_view.load_html_string ((string)message.response_body.data, url);
		this.web_view.open (url);
	}

	// deal with someone activating the url/command bar
	private void on_activate () {
		var url = this.url_bar.text;
		// Check for a command
		if (url.substring(0,1) == ":") {
			ProcessCommand (url);
		} else {
			// we have a url or search
			if (!this.protocol_regex.match (url)) {
				if (!this.search_check_regex.match (url)) {
					url = "http://www.google.co.uk/search?q="+url;
				} else {
					url = "%s://%s".printf (winks.DEFAULT_PROTOCOL, url);
				}
			}
			// load the url
			load_url (url);
		}
		this.scrolled_window.grab_focus ();
	}

	// process a command
	public void ProcessCommand (string PassedCmd) {
		string[] command_and_args = PassedCmd.split(" ");
		string the_command = command_and_args[0];
		string the_argument = "";
		if (command_and_args[1] != null) {
			if (!this.protocol_regex.match (command_and_args[1])) {
				the_argument = (" http://"+command_and_args[1]);
			}
		}

		switch (the_command) {
			case ":quit":
			case ":q":
				Gtk.main_quit ();
			break;

			case ":new":
			case ":n":
				try {
					GLib.Process.spawn_command_line_async ("winks"+the_argument);
				} catch (GLib.SpawnError e) {
					stderr.printf ("Could not spawn new process: %s\n", e.message);
				}
			break;

			default:
				this.status_bar.set_text ("'"+PassedCmd+"' Unknown Command | "+VERSION_STRING);
			break;
		}
	}

	// start the ball rolling
	public void start (string passed_url) {
		show_all ();
		if (this.protocol_regex.match (passed_url)) {
			//load the passed url
			load_url (passed_url);
		} else {
			//load the homepage
			load_url (winks.HOME_URL);
		}
		this.scrolled_window.grab_focus ();
	}

	// main function
	public static int main (string[] args) {
		Gtk.init (ref args);

		var browser = new winks ();

		if (args[1] != null) {
			browser.start (args[1]); 
		} else {
			browser.start (winks.HOME_URL);
		}

		Gtk.main ();

		return 0;
	}
}
