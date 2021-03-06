package tryhaxe;
class Api
{
	var program : tryhaxe.api.Program;
	var dir     : String;
	public  static var base:String;
	public  static var root:String;
	public  static var tmp = "../tmp";
	private static var alphaNum = ~/[^a-zA-Z0-9]/;
	
	public function new() {}


	public static inline function checkSanity (s:String) {
		if (alphaNum.match(s))
			throw "Unauthorized :" + s + "";
	}


	public function doCompiler() {
		var ctx = new haxe.remoting.Context();
    	ctx.addObject("Compiler",new tryhaxe.api.Compiler());
    	haxe.remoting.HttpConnection.handleRequest(ctx);
	}


	public function doProgram (id:String , d:haxe.web.Dispatch) {
		checkSanity(id);
		dir = tmp + "/" + id;
		if (sys.FileSystem.exists(dir) && sys.FileSystem.isDirectory(dir))
			d.dispatch({
				doRun: runProgram,
				doGet: getProgram
			});
		else
			php.Web.setReturnCode(404);
	}


	function runProgram () { php.Lib.print(sys.io.File.getContent(dir+'/index.html')); }
	function getProgram () { php.Lib.print(sys.io.File.getContent(dir+'/program')); }


	public static inline function start (appendRoot = '/app')
	{
		var params = php.Web.getParams();
        var url = params.get('_url');
        params.remove('_url');

        if (params.exists('_root')) {
            Api.root = params.get('_root');
            Api.base = Api.root + appendRoot;
        } else {
            var base:String = untyped __php__("$_SERVER['SCRIPT_NAME']");
            var spl = base.split("/");
            spl.pop();

            Api.base = spl.join("/");
            spl.pop();
            Api.root = spl.join("/");
        }

        haxe.web.Dispatch.run(url, params, new Api());
	}
}