package js.codemirror;

typedef Element = #if haxe3 js.html.HtmlElement #else js.Dom.HtmlDom #end;
typedef TextArea = #if haxe3 js.html.TextAreaElement #else js.Dom.Textarea #end;

typedef Completions = {
	list : Array<String>,
	from : Pos,
	to : Pos,
};

typedef Pos = {
	line : Int,
	ch : Int
};
typedef CursosPos = {
	line : Int,
	ch : Int,
	?hitSide : Bool
};
typedef LinkedDocOptions = {
	?sharedHist : Bool,
	?from : Int,
	?to : Int,
	?mode : Dynamic
};
typedef HistorySize = {
	undo : Int,
	redo : Int
};

typedef TextMarkerOptions = {
	?className : String,
	?inclusiveLeft : Bool,
	?inclusiveRight : Bool,
	?atomic : Bool,
	?collapsed : Bool,
	?clearOnEnter : Bool,
	?replaceWith : Element,
	?handleMouseEvents : Bool,
	?readOnly : Bool,
	?addToHistory : Bool,
	?startStyle : String,
	?endStyle : String,
	?shared : Bool
};
typedef BookmarkOptions = {
	?widget : Element,
	?insertLeft : Bool
};

typedef LineHandle = {
	line : Int,
};
typedef LineInfo = {
	line : Int,
	handle : Dynamic, //FIXME LineHandle?
	text : String,
	gutterMarkers : Dynamic,
	textClass : String,
	bgClass : String,
	widgets : Array<LineWidget>
};
typedef LineWidgetOptions = {
	?coverGutter : Bool,
	?noHScroll : Bool,
	?above : Bool,
	?showIfHidden : Bool,
	?handleMouseEvents : Bool
};

typedef ScrollInfo = {
	left : Float,
	top : Float,
	width : Float,
	height : Float,
	clientWidth : Float,
	clientHeight : Float,
};
typedef Box = {
	left: Float,
	right: Float,
	top: Float,
	bottom: Float
};
typedef CursorCoords = {
	left : Float,
	top : Float,
	bottom : Float
};
typedef Token = {
	start : Int,
	end : Int,
	string : String,
	state : Mode
};
typedef HintOutput = {
	list : Array<String>,
	from : Pos,
	to : Pos
};
typedef HintOptions = {
	async : Bool,
	completeSingle : Bool,
	alignWithWord : Bool,
	customKeys : Dynamic,
};

@:native('CodeMirror') extern class CodeMirror {
	public static var version (default, null) : String;
	public static var defaults (default,null) : Dynamic;
	public static var commands (default,null) : Dynamic<CodeMirror->Void>;

	public static function fromTextArea( textarea : TextArea , ?config : Dynamic ) : CodeMirror;
	public static function defineExtension(name:String, value:Dynamic) : Void;
	public static function defineDocExtension(name:String, value:Dynamic) : Void;
	public static function defineOption(name:String, def:Dynamic, updateFunc:Void->Void) : Void;
	public static function defineInitHook(f:Void->Void) : Void;

	public function hasFocus() : Bool;
	public function findPosH(start:Pos, amount:Int, unit:String, visually:Bool) : CursosPos;
	public function findPosV(start:Pos, amount:Int, unit:String) : CursosPos;
	
	public function setOption( n:String, v:Dynamic ) : Void;
	public function getOption( n:String ) : Dynamic;
	public function addKeyMap(map:Dynamic, bottom:Bool) : Void;
	public function removeKeyMap(map:Dynamic) : Void;
	
	@:overload(function(mode:Dynamic, ?options:Dynamic):Void{})
	public function addOverlay(mode:String, ?options:Dynamic) : Void;
	
	@:overload(function(mode:Dynamic):Void{})
	public function removeOverlay(mode:String) : Void;
	public function on(type:String, f:Dynamic) : Void;
	public function off(type:String, f:Dynamic) : Void;
	
	public function getDoc() : Doc;
	public function swapDoc(doc:Doc) : Doc;
	
	@:overload(function(line:LineHandle, gutterId:String, value:Element):LineHandle{})
	public function setGutterMarker(line:Int, gutterId:String, value:Element) : LineHandle;
	
	public function clearGutter(gutterId:String) : Void;
	
	@:overload(function(line:LineHandle, where:String, className:String):LineHandle{})
	public function addLineClass(line:Int, where:String, className:String) : LineHandle;
	
	@:overload(function(line:LineHandle, where:String, className:String):LineHandle{})
	public function removeLineClass(line:Int, where:String, className:String) : LineHandle;

	@:overload(function(line:LineHandle):LineInfo{})
	public function lineInfo(line:Int) : LineInfo;
	
	public function addWidget(pos:Pos, node:Element, scrollIntoView : Bool) : Void;
	@:overload(function(line:LineHandle, node:Element, ?options:LineWidgetOptions) : LineWidget{})
	public function addLineWidget(line:Int, node:Element, ?options:LineWidgetOptions) : LineWidget;
	
	@:overload(function(width:String, height:String) : Void{})
	@:overload(function(width:Float, height:String) : Void{})
	@:overload(function(width:String, height:Float) : Void{})
	public function setSize(width:Float, height:Float) : Void;
	
	public function scrollTo(x:Float, y:Float) : Void;
	public function getScrollInfo() : ScrollInfo;

	@:overload(function(pos:Box, ?margin:Float) : Void{})
	public function scrollIntoView(pos:Pos, ?margin:Float) : Void;
	
	@:overload(function(where:Pos, mode:String) : CursorCoords{})
	public function cursorCoords(where:Bool, mode:String) : CursorCoords;

	public function charCoords(pos:Pos, ?mode:String) : Box;
	public function coordsChar(o:{left:Float,top:Float}, ?mode:String) : Pos;
	public function lineAtHeight(height:Float, ?mode:String) : Float;
	public function defaultTextHeight() : Float;
	public function defaultCharWidth() : Float;
	public function getViewport() : {from:Float, to:Float};
	public function refresh() : Void;

	public function getTokenAt(pos:Pos) : Token;
	public function getStateAfter(?line:Int) : Dynamic; //Mode?
	
	public function operation(f:Void->Dynamic) : Dynamic;
	public function indentLine(line:Int, ?dir:String) : Void;
	public function toggleOverwrite(?v:Bool) : Void;
	public function focus() : Void;
	public function getWrapperElement() : Element;
	public function getScrollerElement() : Element;
	public function getGutterElement() : Element;

	//EXTENSIONS
	public static function showHint (cm:CodeMirror, f:CodeMirror->Dynamic->HintOutput, ?options:HintOptions) : Void;
}

@:native('Doc') extern class Doc {
	public function getValue(?sep:String) : String;
	public function setValue( v : String ) : Void;
	public function getRange(from:Pos,to:Pos, ?sep:String) : String;
	public function replaceRange(v:String, from:Pos, to:Pos) : Void;
	
	public function getLine(n:Int) : String;
	public function setLine(n:Int, v:String) : Void;
	public function removeLine(n:Int) : Void;
	public function lineCount() : Int;
	public function firstLine() : Int;
	public function lastLine() : Int;

	public function getLineHandle(n:Int) : LineHandle;
	public function getLineNumber(h:LineHandle) : Int;
	
	@:overload(function(s:Int,e:Int,f:LineHandle->Void):Void{})
	public function eachLine(f:LineHandle->Void) : Void;
	
	public function markClean() : Void;
	public function isClean() : Bool;

	public function getSelection() : String;
	public function replaceSelection(v:String, ?collapse:String) : Void;
	
	public function getCursor( ?start : Bool ) : Pos;
	public function somethingSelected() : Bool;
	public function setCursor(pos:Pos) : Void;
	
	public function setSelction(anchor:Pos, head:Pos) : Void;
	public function extendSelection(from:Pos, ?to:Pos) : Void;
	public function setExtending(v:Bool) : Void;

	public function getEditor() : CodeMirror;
	public function copy(copyHistory:Bool) : Doc;
	public function linkedDoc(options:LinkedDocOptions) : Doc;
	public function unlinkDoc(doc:Doc) : Void;
	public function iterLinkedDocs(f:Doc->Bool->Void) : Void;

	public function undo() : Void;
	public function redo() : Void;
	public function historySize() : HistorySize;
	public function clearHistory() : Void;
	public function getHistory() : Dynamic;
	public function setHistory(h:Dynamic) : Void;

	public function markText(from:Pos, to:Pos, ?options:TextMarkerOptions ) : TextMarker;
	public function setBookmark(pos:Pos, ?options:BookmarkOptions) : TextMarker;
	public function findMarksAt(pos:Pos) : Array<TextMarker>;
	public function getAllMarks() : Array<TextMarker>;
	
	public function getMode() : Mode;

	public function posFromIndex(i:Int) : Pos;
	public function indexFromPos(o:Pos) : Int;
}

@:native('LineWidget') extern class LineWidget {
	public var line : LineHandle;
	public function clear () : Void;
	public function changed () : Void;
}
@:native('TextMarker') extern class TextMarker {
	public function clear () : Void;
	public function find () : Pos;
	public function changed () : Void;
	public function attachLine (l:LineHandle) : Void;
	public function detachLine (l:LineHandle) : Void;
}
@:native('LeafChunk') extern class LeafChunk {
	public function chunkSize () : Int;
	public function removeInner (at:Int, n:Int) : Void;
	public function collapse (lines:Array<LineHandle>) : Void;
	public function insertInner (at:Int, lines:Array<LineHandle>, height:Int) : Void;
	public function iterN (at:Int, n:Int, f:LineHandle->Bool) : Bool;
}
@:native('Mode') extern class Mode {
	public function eol () : Bool;
	public function sol() : Bool;
	public function peek() : String;
	public function next() : String;
	@:overload(function(match:EReg) : String{})
	@:overload(function(match:String->Bool) : String{})
	public function eat(match:String) : String;
	
	@:overload(function(match:EReg) : String{})
	@:overload(function(match:String->Bool) : String{})
	public function eatWhile(match:String) : String;
	
	public function eatSpace() : Bool;
	public function skipToEnd() : Void;
	public function skipTo(ch:String) : Bool;
	
	@:overload(function (pattern:String, ?consume:Bool) : Array<String>{})
	public function match(pattern:String, ?consume:Bool, ?caseFold:Bool) : Bool;
	
	public function backUp(n:Int) : Void;
	public function column() : Int;
	public function indentation() : Int;
	public function current() : String;
}
