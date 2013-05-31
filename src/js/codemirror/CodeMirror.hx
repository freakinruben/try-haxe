package js.codemirror;

import js.Dom;

typedef Completions = {
	list : Array<String>,
	from : Pos,
	to : Pos,
}

typedef Pos = {
	line : Int,
	ch : Int
}

typedef MarkedText = {
	clear : Void->Void,
	find : Void->Pos
}

typedef LineHandle = {};

typedef ChangeEvent = {
	from : Pos,
	to : Pos,
	text : Array<String>,
	?next : ChangeEvent
}

@:native('CodeMirror') extern class CodeMirror {

	public static var commands (default,null) : Dynamic<CodeMirror->Void>;
	public static function simpleHint( cm : CodeMirror , getCompletions : CodeMirror -> Completions ) : Void;

	public static function fromTextArea( textarea : Textarea , ?config : Dynamic ) : CodeMirror;

	public function setValue( v : String ) : Void;
	public function getValue() : String;
	public function setOption( n:String, v:Dynamic ) : Void;
	public function getOption( n:String ) : Dynamic;
	public function refresh() : Void;

	public function getCursor( ?start : Bool ) : Pos;

	public function markText(from : Pos, to : Pos, className : String ) : MarkedText;
	
	public function setMarker( line : Int , ?text : String , ?className : String ) : LineHandle;
	@:overload( function( line : LineHandle ) : Void {})
	public function clearMarker(line:Int) : Void;

	public function getWrapperElement() : js.HtmlDom;

	public function somethingSelected() : Bool;
	public function focus() : Void;

}