class Api
{
	public static var base:String;
	public static var root:String;
	public static var tmp = "../tmp";
	
	public function new () {}
	public function doProgram (id:String , d:haxe.web.Dispatch) {}	// FIXME: remove line and compiler complains about missing haxe.web.Dispatch class in App


	public static function checkSanity (s:String) {
		var alphaNum = ~/[^a-zA-Z0-9]/;
		if (alphaNum.match(s)) throw "Unauthorized :" + s + "";
	}
}