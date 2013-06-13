package tryhaxe.api;

typedef Program = {
	uid : String,
	main : Module,
	target : Target,
	options:Array<String>,	//compiler options
//	?modules : Hash<Module>,
}

typedef Module = {
	name : String,
	source : String
}

enum Target {
	JS( name : String );
	SWF( name : String , ?version : Int );
}

typedef Output = {
	uid : String,
	stderr : String,
	stdout : String,
	args : Array<String>,
	errors : Array<String>,
	success : Bool,
	href : String,
	source : String
}

typedef Compiled = {
	out : Output,
	program : Program,
}