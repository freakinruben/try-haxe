import api.Program;
 using Lambda;

typedef AvailableLibs = {
	js : Array<String>,
	swf : Array<String>
}

class Libs
{
	public static var available : AvailableLibs = {
		js : [
			"jeash",
			"actuate",
			"selecthx",
			"modernizr",
			"browserhx",
			"format",
			"three.js"
		],
		swf : [
			"actuate",
			"format",
			"away3d",
			"starling"
		]
	};

	/* array of lib names */
	public static var defaultChecked : Array<String> = ["jeash"];
}