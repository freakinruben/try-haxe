class Api {

	var program:api.Program;
	var dir:String;
	public static var base:String;
	public static var root:String;
	public static var tmp = "../tmp";
	
	public function new() {}


	public static function checkSanity (s:String) {
		var alphaNum = ~/[^a-zA-Z0-9]/;
		if (alphaNum.match(s)) throw "Unauthorized :" + s + "";
	}


	public function doCompiler() {
		var ctx = new haxe.remoting.Context();
    	ctx.addObject("Compiler",new api.Compiler());
    	haxe.remoting.HttpConnection.handleRequest(ctx);
	}


	function notFound() {
		php.Web.setReturnCode(404);
	}


	public function doProgram (id:String , d:haxe.web.Dispatch) {
		checkSanity (id);
		dir = tmp + "/" + id;
		if (sys.FileSystem.exists (dir) && sys.FileSystem.isDirectory (dir))
			d.dispatch({
				doRun: runProgram,
				doGet: getProgram
			});
		else
			notFound();
	}


	public function runProgram () {
		php.Lib.print(sys.io.File.getContent(dir+'/index.html'));
	}


	public function getProgram () {
		php.Lib.print(sys.io.File.getContent(dir+'/program'));
	}
}