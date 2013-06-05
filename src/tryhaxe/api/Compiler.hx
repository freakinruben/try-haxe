package tryhaxe.api;
 import sys.FileSystem;
 import sys.io.File;
  using Lambda;
  using Std;


class Compiler
{
	private static var forbidden = ~/@([^:]*):([^a-z]*)(macro|build|autoBuild|file|audio|bitmap|access)/;
	var tmpDir   : String;
	var mainFile : String;

	public function new() {}

	static inline function checkMacros (s:String) {
		if (forbidden.match(s))
			throw "Unauthorized : @:"+forbidden.matched(3)+"";  
	}


	private function randomUID (p:Program) {
		p.uid = haxe.Md5.encode(Math.random().string() + Date.now().getTime().string());
		if (FileSystem.exists(Api.tmp + "/" + p.uid))
			randomUID(p);
	}


	private function programUID (p:Program) {
		p.uid = null;
		p.uid = haxe.Md5.encode(haxe.Serializer.run(p));
	}


	private function prepareProgram (program:Program)
	{
		tmpDir = Api.tmp + "/" + program.uid + "/";
		Api.checkSanity(program.uid);
		Api.checkSanity(program.main.name);
 		
		if (!FileSystem.isDirectory(tmpDir)) {
			FileSystem.createDirectory(tmpDir);
			Sys.command("chmod 707 "+tmpDir);
		}

		mainFile   = tmpDir + program.main.name + ".hx";
		var source = program.main.source;
		checkMacros(source);
		
		program.main.source = null;
		File.saveContent(mainFile, source);
		File.saveContent(tmpDir + "program", haxe.Serializer.run(program));
		program.main.source = source;
	}


	@:keep public function getProgram (uid:String):Program
	{
		Api.checkSanity(uid);
		if (!FileSystem.isDirectory(Api.tmp + "/" + uid))
			return null;
	
		tmpDir = Api.tmp + "/" + uid + "/";
		var p:Program = haxe.Unserializer.run(File.getContent(tmpDir + "program"));
		mainFile = tmpDir + p.main.name + ".hx";
		p.main.source = File.getContent(mainFile);
		return p;
	}


	@:keep public function autocomplete (program:Program, idx:Int) : Array<String>
	{
		randomUID(program);
		try 				{ prepareProgram(program); }
		catch (err:String) 	{ return []; }

		var args   = [
			"-cp", tmpDir,
			"-main", program.main.name,
			"--no-opt",
			"-v",
			//"--no-output",
			"--display", tmpDir + program.main.name + ".hx@" + idx
		];

		switch (program.target) {
			case JS(_):
				args.push("-js");
				args.push("dummy.js");

			case SWF(_, version):
				args.push("-swf");
				args.push("dummy.swf");
				args.push("-swf-version");
				args.push(version.string());
		}
		var out = runHaxe(args = args.concat(program.options));
		try {
			FileSystem.deleteFile(tmpDir+"program");
			FileSystem.deleteFile(tmpDir+program.main.name+".hx");
			FileSystem.deleteDirectory(tmpDir);
			var xml   = new haxe.xml.Fast(Xml.parse(out.err).firstChild());
			var words = [];
			for(e in xml.nodes.i) {
				var w = e.att.n;
				if (!words.has(w))
					words.push(w);
			}
			return words;
		} catch (e:Dynamic) { return []; }
	}


	@:keep public function compile (program:Program) {
		programUID(program);
		try { prepareProgram(program); }
		catch (err:String) {
			return {
				uid:     program.uid,
				args:    [],
				stderr:  err,
				stdout:  "",
				errors:  [err],
				success: false,
				href:    "",
				source:  ""
			}
		}

		var args = [
			"-cp", tmpDir,
			"-main", program.main.name,
			"--times",
#if haxe3	"-dce", "full"
#else		"--dead-code-elimination" #end
		];

		var outputPath : String;
		var htmlPath : String = tmpDir + "index.html";
		var runUrl = Api.base + "/program/"+program.uid+"/run";
		
		var html = {head:[], body:[]};

		switch(program.target) {
			case JS(name):
				Api.checkSanity(name);
				outputPath = tmpDir + name + ".js";
				args.push("-js");	args.push(outputPath);
#if !haxe3		args.push("--js-modern"); #end //default enabled in haxe3
				args.push("-D");	args.push("noEmbedJS");
				html.body.push("<script src='//ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js'></script>");
				html.body.push('<script>window.jQuery || document.write("<script src=\'../../../lib/jquery.min.js\'><\\/script>")</script>');

			case SWF(name, version):
				Api.checkSanity(name);
				outputPath = tmpDir + name + ".swf";
				args.push("-swf");			args.push(outputPath);
				args.push("-swf-version");	args.push(version.string());
				args.push("-debug");
				html.head.push("<link rel='stylesheet' href='"+Api.root+"/swf.css' type='text/css'/>");
				html.head.push("<script src='"+Api.root+"/lib/swfobject.js'></script>");
				html.head.push('<script type="text/javascript">swfobject.embedSWF("'+Api.base+"/"+outputPath+'?r='+Math.random()+'", "flashContent", "100%", "100%", "'+version+'.0.0", null, {}, {wmode:"direct", scale:"noscale"})</script>');
				html.body.push('<div id="flashContent"><p><a href="http://www.adobe.com/go/getflashplayer"><img src="http://www.adobe.com/images/shared/download_buttons/get_flash_player.gif" alt="Get Adobe Flash player" /></a></p></div>');
		}
		var out = runHaxe(args = args.concat(program.options));
		var err = out.err.split(tmpDir).join("");
		var errors = err.split("\n");

		var output = {
				uid:     program.uid,
				stderr:  err,
				stdout:  out.out,
				args:    args,
				errors:  errors,
				success: out.exitCode == 0,
				href:    out.exitCode == 0 ? runUrl : "",
				source:  ""};

		if (out.exitCode == 0)
		{
			switch (program.target) {
				case JS(_):
					output.source = File.getContent(outputPath);
					html.body.push("<script>" + output.source + "</script>");
				default:
			}
			var h = new StringBuf();
			h.add("<html>\n\t<head>\n\t\t<title>Haxe Run</title>");
			for (i in html.head) { h.add("\n\t\t"); h.add(i); }
			h.add("\n\t</head>\n\t<body>");
			for (i in html.body) { h.add("\n\t\t"); h.add(i); } 
			h.add('\n\t</body>\n</html>');

			File.saveContent(htmlPath, h.toString());
		}
		else if (FileSystem.exists(htmlPath))
			FileSystem.deleteFile(htmlPath);
		
		return output;
	}


	private inline function runHaxe (args:Array<String>)
	{
		args.push("--connect"); args.push("6789");
		var proc = new sys.io.Process("haxe", args);
		return {
			proc:     proc,
			exitCode: proc.exitCode(),
			out:      proc.stdout.readAll().toString(),
			err:      proc.stderr.readAll().toString()
		};
	}
}