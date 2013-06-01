import api.Program;
import haxe.remoting.HttpAsyncConnection;
import js.codemirror.CodeMirror;
import js.JQuery;
 using Lambda;
 using StringTools;

typedef EditorOptions = {
    className: String,
    editorKeys: Dynamic,
    targets: Int,
    defaultTarget: Int,
    haxeCode: Dynamic,
    jsOutput: Dynamic,
    apiURI: String,
    root: String
};


class Editor
{
    private static var loadedResources = false;
    public static inline var SWF = 0x01;
    public static inline var JS  = 0x02;

    /* Default options for setting up CodeMirror for the haxe-source */
    public static inline function haxeOptions () { return {theme: "default", lineWrapping: true, lineNumbers: true,  mode: "haxe"}; }
    /* Default options for setting up CodeMirror for the generated js-output */
    public static inline function jsOptions ()   { return {theme: "default", lineWrapping: true, lineNumbers: false, mode: "javascript", readOnly: true}; }
    /* Default key-bindings for CodeMirror of the haxe-source */
    public static inline function defaultKeys () { return {
                "Ctrl-Space" : "autocomplete",
                "Ctrl-Enter" : "compile",
                "F8" : "compile",
                "F5" : "compile",
                "F11" : "togglefullscreen"
    };}
    /* Default options for creating an haxe-editor */
    public static inline function defaultOptions () : EditorOptions { return {
        className: 'Test',
        editorKeys: defaultKeys,
        targets: SWF | JS,
        defaultTarget: JS,
        haxeCode: haxeOptions(),
        jsOutput: jsOptions(),
        apiURI: "/compiler",
        root: ""
    };}


    //
    // CALLBACK HANDLERS
    //

    /* Called before program is compiled */
    public var handleCompile  : Void -> Void;
    /* Called when program is compiled */
    public var handleCompiled : Void -> Void;
    /* Called when a compiled program is loaded and ready. UI needs to update libs/target etc. */
    public var handleLoaded   : Void -> Void;

    public var options    (default, null) : EditorOptions;
    public var haxeSource (default, null) : CodeMirror;
    public var jsSource   (default, null) : CodeMirror;
    public var program    (default, null) : Program;
    public var output     (default, null) : Output;

    private var cnx : HttpAsyncConnection;
    private var markers : Array<MarkedText>;
    private var lineHandles : Array<LineHandle>;
    private var completions : Array<String>;
    private var completionIndex : Int;


    /**
     * @param id          id of the wrapper element around the textfield
     * @param o             editor-options
     */
    public function new (id:String, o:EditorOptions)
    {
        loadResources(options = o);
        markers = [];
        lineHandles = [];

        CodeMirror.commands.autocomplete = autocomplete;
        CodeMirror.commands.compile = function(_) compile();
        CodeMirror.commands.togglefullscreen = toggleFullscreenSource;

        // Initialize UI
        haxeSource = CodeMirror.fromTextArea( cast new JQuery("#"+id+" textarea[name='hx-source']")[0], options.haxeCode );
        haxeSource.setOption("onChange",  onCodeChange);
        haxeSource.setOption("extraKeys", options.editorKeys);

        if (options.jsOutput != null)
            jsSource = CodeMirror.fromTextArea(cast new JQuery("#"+id+" textarea[name='js-source']")[0], options.jsOutput);
        
        cnx = HttpAsyncConnection.urlConnect(options.apiURI);
        onProgramLoaded({
            uid: null,
            main: {
                name:   options.className,
                source: haxeSource.getValue()
            },
            target: toTarget(options.defaultTarget),
            libs: new Array()
        });
    }


    public inline function dispose ()
    {
        haxeSource.setOption("extraKeys", null);
        haxeSource.setOption("onChange", null); //FIXME doesn't seem to remove eventlistener
        haxeSource = null;
        jsSource = null;

        jsSource = null;
        options = null;
        cnx = null;
        program = null;
        output = null;

        handleLoaded = null;
        handleCompile = null;
        handleCompiled = null;
    }


    public inline function toTarget (target:Int) {
        var n = options.className.toLowerCase();
        return switch(target) {
            case SWF: api.Program.Target.SWF(n,11);
            case JS:  api.Program.Target.JS(n);
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


    public function fullscreen () {
         untyped __js__("var el = window.document.documentElement;
                        var rfs = el.requestFullScreen || el.webkitRequestFullScreen || el.mozRequestFullScreen;
                        rfs.call(el); ");
    }

    private function toggleFullscreenSource (_) {
        new JQuery("body").toggleClass("fullscreen-source");
        haxeSource.refresh();
        fullscreen();
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


    private function onProgramLoaded (p:Program) if (p != null)
    {
        program = p;        // sharing
        p.uid   = null;     // auto-fork

        haxeSource.setValue(p.main.source);
        

        if (handleLoaded != null)
            handleLoaded();
    }




    //
    // AUTOCOMPLETE
    //

    /**
     * updates program-object before compiling
     */
    private function updateProgram ()
    {
        program.main.source = haxeSource.getValue();
        if (handleCompile != null)
            handleCompile();
    }


    private function autocomplete (cm:CodeMirror)
    {
        updateProgram();
        var src = cm.getValue();

        var idx = SourceTools.getAutocompleteIndex(src, cm.getCursor());
        if (idx == null)
            return;

        if (idx == completionIndex) {
            displayCompletions(cm, completions);
            return;
        }
        completionIndex = idx;
        if (src.length > 1000)
            program.main.source = src.substring(0, completionIndex + 1);
        
        cnx.Compiler.autocomplete.call([program, idx], function (comps) displayCompletions(cm, comps));
    }


    private function showHint (cm:CodeMirror)
    {
        var src = cm.getValue();
        var cursor = cm.getCursor();
        var from = SourceTools.indexToPos(src, SourceTools.getAutocompleteIndex(src, cursor));
        var to = cm.getCursor();

        var token = src.substring(SourceTools.posToIndex(src, from), SourceTools.posToIndex(src, to));
        var list = [];

        for (c in completions)
            if (c.toLowerCase().startsWith(token.toLowerCase())) {
                list.push(c);
            }

        return {list: list, from: from, to: to};
    }


    private function displayCompletions (cm:CodeMirror, comps:Array<String>)
    {
        completions = comps;
        CodeMirror.simpleHint(cm , showHint);
    }


    private function onCodeChange (cm:CodeMirror, e:js.codemirror.CodeMirror.ChangeEvent)
        if (e.text[0].trim().endsWith(".")) {
            autocomplete(haxeSource);
        }



    //
    // COMPILE
    //

    public function compile () //(?e)
    {
        //if (e != null) e.preventDefault();
        clearErrors();
        updateProgram();
        trace(cnx.Compiler.compile);
        cnx.Compiler.compile.call( [program] , onCompiled );
    }


    public function onCompiled (o:Output)
    {
        output = o;
        program.uid = o.uid;
        if (!o.success)
            markErrors();
        else {
            jsSource.setValue(o.source);
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
        for (l in lineHandles)  haxeSource.clearMarker(l);
        markers = [];
    }


    private inline function markErrors ()
    {
        var errLine = ~/([^:]*):([0-9]+): characters ([0-9]+)-([0-9]+) :(.*)/g;
        
        for (e in output.errors)
            if (errLine.match(e)) {
                var err = {
                    file: errLine.matched(1),
                    line: Std.parseInt(errLine.matched(2)) - 1,
                    from: Std.parseInt(errLine.matched(3)),
                    to:   Std.parseInt(errLine.matched(4)),
                    msg:  errLine.matched(5)
                };
                if (StringTools.trim(err.file) == options.className + ".hx") {
                    lineHandles.push(haxeSource.setMarker(err.line, "<i class='icon-warning-sign icon-white'></i>" , "error"));
                    markers    .push(haxeSource.markText({line: err.line, ch: err.from}, {line: err.line, ch: err.to}, "error"));
                }
            }
    }

    //
    // LOAD RESOURCES
    //

    private static inline function loadResources (opt:EditorOptions) if (!loadedResources)
    {
        new JQuery('head').append('
            <link rel="stylesheet" href="'+opt.root+'lib/CodeMirror2/lib/codemirror.css"/>
            <link rel="stylesheet" href="'+opt.root+'lib/CodeMirror2/lib/util/simple-hint.css"/>');
        if (opt.haxeCode.theme != 'default')
            new JQuery('head').append('<link rel="stylesheet" href="'+opt.root+'lib/CodeMirror2/theme/'+opt.haxeCode.theme+'.css"/>');
        
        new JQuery('body').append('
            <script src="'+opt.root+'lib/CodeMirror2/lib/codemirror.js"></script>
            <script src="'+opt.root+'lib/CodeMirror2/mode/haxe/haxe.js"></script>
            <script src="'+opt.root+'lib/CodeMirror2/mode/javascript/javascript.js"></script>
            <script src="'+opt.root+'lib/haxe-hint.js"></script>
            <script src="'+opt.root+'lib/bootstrap/js/bootstrap.min.js" ></script>
        ');
        loadedResources = true;
    }
}