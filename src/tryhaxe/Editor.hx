package tryhaxe;
 import tryhaxe.api.Program;
 import haxe.remoting.HttpAsyncConnection;
 import js.codemirror.CodeMirror;
 import js.JQuery;
  using Lambda;
  using StringTools;
  using Std;

typedef EditorOptions = {
    id: String,
    className: String,
    targets: Int,
    defaultTarget: Int,
    haxeCode: CM_Options,
    jsOutput: CM_Options,
    apiURI: String,
    root: String,
    defaultJsArgs: Array<String>,
    defaultSwfArgs: Array<String>,
};


class Editor
{
    private static var loadedResources = false;
    public static inline var SWF = 0x01;
    public static inline var JS  = 0x02;

    /* Default options for setting up CodeMirror for the haxe-source */
    public static inline function haxeOptions () : CM_Options { return {theme: "default", lineWrapping: true, lineNumbers: true,  mode: "haxe", styleActiveLine: true, extraKeys: defaultKeys(), indentUnit: 4}; }
    /* Default options for setting up CodeMirror for the generated js-output */
    public static inline function jsOptions () : CM_Options   { return {theme: "default", lineWrapping: true, lineNumbers: false, mode: "javascript", readOnly: true}; }
    /* Default key-bindings for CodeMirror of the haxe-source */
    public static inline function defaultKeys () { return {
        "Ctrl-Space" : "autocomplete",
        "Ctrl-Enter" : "compile",
        "F8" : "compile",
        "F5" : "compile",
    //  "F11" : "togglefullscreen"
    };}
    /* Default options for creating an haxe-editor */
    public static inline function defaultOptions () : EditorOptions { return {
        id: '',
        className: 'Test',
        targets: SWF | JS,
        defaultTarget: SWF,
        defaultJsArgs: [],
        defaultSwfArgs: [],
        haxeCode: haxeOptions(),
        jsOutput: jsOptions(),
        apiURI: "/compiler",
        root: ""
    };}


    //
    // CALLBACK HANDLERS
    //

    /* Called before program is compiled */
    public var handleCompile   : Void -> Void;
    /* Called when program is compiled */
    public var handleCompiled  : Void -> Void;
    /* Called when autocomplete has loaded */
    public var handleCompleted : Void -> Void;
    /* Called when a compiled program is loaded and ready. UI needs to update libs/target etc. */
    public var handleLoaded    : Void -> Void;

    public var options    (default, null) : EditorOptions;
    public var haxeSource (default, null) : CodeMirror;
    public var haxeDoc    (default, null) : Doc;
    public var jsSource   (default, null) : CodeMirror;
    public var program    (default, null) : Program;
    public var output     (default, null) : Output;

    private var cnx             : HttpAsyncConnection;
    private var markers         : Array<TextMarker>;
    private var lineHandles     : Array<LineHandle>;
    private var completions     : Array<String>;
    private var completionIndex : Int;
    private var initialized     : Bool;


    /**
     * @param id    id of the wrapper element around the textfield
     * @param o     editor-options
     */
    public function new (o:EditorOptions)
    {
        initialized = false;
        options = o;
        cnx = HttpAsyncConnection.urlConnect(o.apiURI);

        if (!loadedResources) {
            loadResources(o);
            haxe.Timer.delay(init, 300); //FIXME css and js files need to be loaded before editor is displayed, otherwise CodeMirror will get wrong size
        } else
            init();
    }


    private function init ()
    {
        markers = [];
        lineHandles = [];

        // Initialize UI
        haxeSource = CodeMirror.fromTextArea( cast new JQuery("#"+options.id+" textarea[name='hx-source']")[0], options.haxeCode );
        haxeSource.on("change", openAutoComplete);
        haxeDoc = haxeSource.getDoc();

#if haxe3   editorMap.set(haxeSource, this);
#else       editorMap.push(this); cmMap.push(haxeSource); #end

        if (options.jsOutput != null)
            jsSource = CodeMirror.fromTextArea(cast new JQuery("#"+options.id+" textarea[name='js-source']")[0], options.jsOutput);

        //listen for changes in fullscreen
    /*  js.Dom.window.documentElement.addEventListener  //TODO, make it possible for multiple editors to go fullscreen. Only active editor should be visible then
        untyped __js__("var api = window.fullScreenApi;
            window.document.documentElement.addEventListener(api.fullScreenEventName, function () {
                if (api.isFullScreen()) { jQuery('body').addClass('fullscreen-runner'); }
                else { jQuery('body').removeClass('fullscreen-runner'); }
            });");*/
        initialized = true;
        if (program != null)    onProgramLoaded({out: output, program: program});
        else                    startNewProgram();
    }


    public inline function dispose ()
    {
        haxeSource.off("change", openAutoComplete);
        haxeSource = null;
        haxeDoc = null;
        jsSource = null;

        jsSource = null;
        options = null;
        cnx = null;
        program = null;
        output = null;

        handleLoaded = handleCompile = handleCompiled = handleCompleted = null;
    }


    public function startNewProgram () if (initialized) {
        onProgramLoaded({out: null, program: {
            uid: null,
            main: {
                name:   options.className,
                source: haxeDoc.getValue()
            },
            target: toTarget(options.defaultTarget),
            options: options.defaultTarget == JS ? options.defaultJsArgs : options.defaultSwfArgs
        }});
    }


    public inline function toTarget (target:Int) {
        var n = options.className.toLowerCase();
        return switch(target) {
            case SWF: tryhaxe.api.Program.Target.SWF(n,11);
            case JS:  tryhaxe.api.Program.Target.JS(n);
            default:  throw "Unknown target "+target;
        };
    }


    public function refreshSources () {
        jsSource.refresh();
        haxeSource.refresh();
    }

    //
    // FULLSCREEN
    //

    public inline function openFullScreen () {
         untyped __js__("window.fullScreenApi.requestFullScreen(window.document.documentElement);");
    }

    //
    // LOAD PROGRAM
    //
    
    /**
     * Loads an already compiled program
     */
    public function loadProgram (hash:String) {
        cnx.Compiler.getProgram.call([hash], onProgramLoaded);
    }


    private function onProgramLoaded (c:Compiled) if (c != null)
    {
        program = c.program; // sharing
        output = c.out;
        if (initialized) {
            haxeDoc.setValue(program.main.source);
            if (handleLoaded != null)
                handleLoaded();

            if (c.out != null)
                onCompiled(c.out);
        }
    }

    //
    // AUTOCOMPLETE
    //

    /**
     * updates program-object before compiling
     */
    private inline function updateProgram ()
    {
        program.main.source = haxeDoc.getValue();
        if (handleCompile != null)
            handleCompile();
    }


    private function autocomplete ()
    {
        updateProgram();
        var src = haxeDoc.getValue();
        var idx = haxeDoc.indexFromPos(haxeDoc.getCursor());
        if (idx == null)
            return;

        if (idx == completionIndex) {
            displayCompletions(completions);
            return;
        }
        completionIndex = idx;
        if (src.length > 1000)
            program.main.source = src.substring(0, idx);
        
        cnx.Compiler.autocomplete.call([program, idx], displayCompletions);
    }


    private static function showHint (cm:CodeMirror, ?opt:Dynamic)
    {
        var doc   = cm.getDoc();
        var editor= cmToEditor(cm);
        var src   = doc.getValue();
        var cursor= doc.indexFromPos(doc.getCursor());
        var from  = SourceTools.getAutocompleteIndex(src, cursor);
        var token = src.substring(from, cursor);
        var list  = [];

        for (c in editor.completions)
            if (c.toLowerCase().startsWith(token.toLowerCase()))
                list.push(c);

        return {list: list, from: doc.posFromIndex(from), to: doc.posFromIndex(cursor)};
    }


    private function displayCompletions (comps:Array<String>)
    {
        completions = comps;
        CodeMirror.showHint(haxeSource, Editor.showHint);
        if (handleCompleted != null)
            handleCompleted();
    }


    private function openAutoComplete (cm:CodeMirror, e:Dynamic) { //js.codemirror.CodeMirror.ChangeEvent)
        if (e.text.pop() == ".")
            autocomplete();
    }



    //
    // COMPILE
    //

    public inline function compile () //(?e)
    {
        //if (e != null) e.preventDefault();
        clearErrors();
        updateProgram();
        cnx.Compiler.compile.call([program], onCompiled);
    }


    public function onCompiled (o:Output)
    {
        output = o;
        program.uid = o.uid;
        if (!o.success)
            markErrors();
        else {
            jsSource.getDoc().setValue(o.source);
            jsSource.refresh();
        }

        if (handleCompiled != null)
            handleCompiled();
    }



    //
    // ERROR HIGHLIGHTING
    //

    private inline function clearErrors ()
    {
        for (m in markers)      m.clear();
        for (l in lineHandles)  haxeSource.setGutterMarker(haxeDoc.getLineNumber(l), null, null);
        markers = [];
    }


    private inline function markErrors ()
    {
        var errLine = ~/([^:]*):([0-9]+): characters ([0-9]+)-([0-9]+) :(.*)/g;
        
        for (e in output.errors)
            if (errLine.match(e)) {
                var err = {
                    file: errLine.matched(1),
                    line: errLine.matched(2).parseInt() - 1,
                    from: errLine.matched(3).parseInt(),
                    to:   errLine.matched(4).parseInt(),
                    msg:  errLine.matched(5)
                };
                if (StringTools.trim(err.file) == options.className + ".hx") {
                    lineHandles.push(haxeSource.setGutterMarker(err.line, "error", cast new JQuery("<i class='icon-warning-sign icon-white'></i>").toArray()[0]));
                    markers    .push(haxeDoc.markText({line: err.line, ch: err.from}, {line: err.line, ch: err.to}, {className: "error"}));
                }
            }
    }

    //
    // LOAD RESOURCES
    //

    private static inline function loadResources (opt:EditorOptions)
    {
        new JQuery('head').append('
            <link rel="stylesheet" href="'+opt.root+'lib/CodeMirror2/lib/codemirror.css"/>
            <link rel="stylesheet" href="'+opt.root+'lib/CodeMirror2/addon/hint/show-hint.css"/>');
        if (opt.haxeCode.theme != 'default')
            new JQuery('head').append('<link rel="stylesheet" href="'+opt.root+'lib/CodeMirror2/theme/'+opt.haxeCode.theme+'.css"/>');
        
        new JQuery('body').append(
            '<script type="text/javascript" src="'+opt.root+'lib/CodeMirror2/lib/codemirror.js"></script>'+
            '<script type="text/javascript" src="'+opt.root+'lib/CodeMirror2/mode/haxe/haxe.js"></script>'+
            '<script type="text/javascript" src="'+opt.root+'lib/CodeMirror2/mode/javascript/javascript.js"></script>'+
            '<script type="text/javascript" src="'+opt.root+'lib/CodeMirror2/addon/hint/show-hint.js"></script>'+
            '<script type="text/javascript" src="'+opt.root+'lib/CodeMirror2/addon/selection/active-line.js"></script>'+
            '<script type="text/javascript" src="'+opt.root+'lib/haxe-hint.js"></script>'
        );

        CodeMirror.commands.autocomplete     = function (cm) cmToEditor(cm).autocomplete();
        CodeMirror.commands.compile          = function (cm) cmToEditor(cm).compile();
    //  CodeMirror.commands.togglefullscreen = function (cm) cmToEditor(cm).togglefullscreen();
        loadedResources = true;
    }

    private static function cmToEditor (cm:CodeMirror) {
#if haxe3   return editorMap.get(cm);
#else       return editorMap[cmMap.indexOf(cm)]; #end
    }

#if haxe3
    private static var editorMap (default, null) : Map<CodeMirror,Editor> = new Map();
#else
    private static var editorMap (default, null) : Array<Editor> = [];
    private static var cmMap     (default, null) : Array<CodeMirror> = [];
#end
}