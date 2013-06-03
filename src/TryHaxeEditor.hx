import api.Program;
import js.JQuery;
 using js.bootstrap.Button;
 using Lambda;
 using Std;

class TryHaxeEditor
{
    var editor : Editor;
    var form : JQuery;
    var messages : JQuery;
    var compileBtn : JQuery;
    var targets : JQuery;
    var libs : JQuery;
    var outDisplay : JQuery;
    var haxeOutput : JQuery;
    var jsTab : JQuery;
    
    var editorId : String;


    public function new (id)
    {
        editorId = "#"+id+" ";
        var options = Editor.defaultOptions();
        options.apiURI = new JQuery("body").data("api") + "/compiler";

        initializeUI();
        editor = new Editor(id, options);

        editor.handleLoaded   = handleLoaded;
        editor.handleCompile  = handleCompile;
        editor.handleCompiled = handleCompiled;

        haxeOutput = new JQuery(editorId+"iframe[name='js-run']");
        messages = new JQuery(editorId+".messages");
        compileBtn = new JQuery(editorId+".compile-btn");
        libs = new JQuery(editorId+".hx-libs");
        targets = new JQuery(editorId+".hx-targets");
        jsTab = new JQuery(editorId+"a[href='.js-source']");
        outDisplay = new JQuery(editorId+".compiler-out");

        new JQuery(editorId+".link-btn").bind("click", function(e) {
            if (new JQuery(e.target).attr('href') == "#")
                e.preventDefault();
        });
        new JQuery(editorId+".fullscreen-btn").bind("click", toggleFullscreenRunner); 
        new JQuery("body").bind("keyup", onKey);
        new JQuery(editorId+"a[data-toggle='tab']").bind("shown", function (_) editor.refreshSources());

        targets.delegate("input.hx-target", "change", changeTarget);
        compileBtn.bind("click", function (_) editor.compile());

        var uid = js.Lib.window.location.hash;
        if (uid.length > 0)
            editor.loadProgram(uid.substr(1));
    }


    public function dispose ()
    {
        editorId = null;
        editor.dispose();
        editor = null;
        form = messages = compileBtn = targets = libs = outDisplay = haxeOutput = jsTab = null;
    }

    
    private function changeTarget (e:JqEvent)
    {
        editor.program.target = editor.toTarget(new JQuery(e.target).val().parseInt());
        updateTargetCheckbox();
    }


    private function updateTargetCheckbox ()
    {
        var target = editor.program.target;
        libs.find(".controls").hide();
        
        var sel:String;
        switch (target) {
            case JS(_): 
                sel = "js";
                jsTab.fadeIn();

            case SWF(_,_) : 
                sel = "swf";
                jsTab.hide();
        }
        new JQuery(editorId+"input#target-"+editorId.substr(1,editorId.length - 2)+"-"+sel).attr('checked' ,'checked');
        libs.find("."+sel+"-libs").fadeIn();
    }

    
    private function initLibs (available:Array<String>, target:String)
    {
        var el = libs.find("."+target+"-libs");
        for (lib in available)
            el.append(
                '<label class="checkbox"><input class="lib" type="checkbox" value="' + lib + '" ' 
                + ((Libs.defaultChecked.has(lib) /*|| selectedLib(lib)*/) ? "checked='checked'" : "") 
                + '" /> ' + lib
                + "<span class='help-inline'><a href='" + (lib == null ? "http://lib.haxe.org/p/" + lib : lib) 
                +"' target='_blank'><i class='icon-question-sign'></i></a></span>"
                + "</label>"
               );
    }


    private function onProgramLoaded (p:Program)
    {
        libs.find('input.lib').removeAttr('checked');
        if (p.options != null)
            for (lib in libs.find("input.lib"))
                if (p.options.has(lib.val()))
                    lib.attr("checked","checked");
    }


    public function toggleFullscreenRunner (e:JqEvent) {
        var _this = new JQuery(e.target);
        e.preventDefault();
        if (_this.attr('href') != "#") {
            new JQuery("body").addClass("fullscreen-runner");
            editor.fullscreen();
        }
    }


    public function onKey (e:JqEvent)
    {
         /*if (e.keyCode == 27) { // Escape
                new JQuery("body").removeClass("fullscreen-source fullscreen-runner");
         }*/
         if (e.keyCode == 122) {
                var b = new JQuery("body");
                if (b.hasClass("fullscreen-runner")) {
                    b.removeClass("fullscreen-runner");
                }
         }
         if ((e.ctrlKey && e.keyCode == 13) || e.keyCode == 119) { // Ctrl+Enter and F8
                e.preventDefault();
                editor.compile();
         }
    }


    //
    // EDITOR HANDLERS
    //

    private function handleLoaded ()
    {
        updateTargetCheckbox();
        initLibs(Libs.available.js, "js");
        initLibs(Libs.available.swf, "swf");
    }


    private function handleCompile ()
    {
        messages.fadeOut(0);
        compileBtn.buttonLoading();

        var libs = new Array();
        var sel = switch (editor.program.target) {
            case JS(_): "js";
            case SWF(_,_) : "swf";
        }
        var inputs = new JQuery(editorId+".hx-options .hx-libs ."+sel+"-libs input.lib:checked");
        for (i in inputs) {
            libs.push('-lib');
            libs.push(i.val());
        }
        editor.program.options = libs;
    }


    private function handleCompiled ()
    {
        var o = editor.output;
        js.Lib.window.location.hash = "#" + o.uid;
        
        var jsSourceElem = new JQuery(editor.jsSource.getWrapperElement());
        var msg : Array<String> = [];
        var msgType : String = "";

        outDisplay.show();
        if (o.success) {
            msgType = "success";
            jsSourceElem.show();
            haxeOutput.show();
            
            switch (editor.program.target) {
                case JS(_): jsTab.show();
                default:    jsTab.hide();
            }

            haxeOutput.attr("src", o.href + "?r=" + Math.random().string());
            new JQuery(editorId+".link-btn, .fullscreen-btn")
                .buttonReset()
                .attr("href", o.href + "?r=" + Math.random().string());
        } else {
            msg = o.stderr.split("\n");
            msgType = "error";
            haxeOutput.hide();
            jsTab.hide();
            jsSourceElem.hide();

            haxeOutput.attr("src", "about:blank");
            new JQuery(editorId+".link-btn, .fullscreen-btn")
                .addClass("disabled")
                .attr("href", "#");
        }
        var message = o.success ? "Build success!" : "Build failure";
        messages.html("<div class='alert alert-"+msgType+"'><h4 class='alert-heading'>" + message + "</h4><div class='message'></div></div>");
        for (m in msg)
            messages.find(".message").append(new JQuery("<div>").text(m));
        
        if (o.success && o.stderr != null)
            messages.append(new JQuery("<pre>").text(o.stderr));

        messages.fadeIn();
        compileBtn.buttonReset();
    }


    private inline function initializeUI ()
    {
        var name = editorId.substr(1, editorId.length - 2); //FIXME editorId.substr(1, -2); seems broken for JS. Still the case for haxe3?
        var textarea = new JQuery(editorId+" textarea[name='hx-source']")
            .wrap('<div class="row-fluid">')
            .wrap('<div class="compiler-in span6" />')
            .wrap('<div class="tab-content" />')
            .wrap('<div class="tab-pane hx-source active" />')
            .parent()
            .after('<div class="tab-pane hx-options">
                    <form class="form-horizontal">
                        <div class="control-group hx-targets">
                            <label class="control-label" for="libs-checkbox">Target</label>
                            <div class="controls">
                                <input type="radio" name="target-'+name+'" class="hx-target" id="target-'+name+'-js" value="'+Editor.JS+'"></input><label for="target-'+name+'-js" class="radio inline">JS</label>
                                <input type="radio" name="target-'+name+'" class="hx-target" id="target-'+name+'-swf" value="'+Editor.SWF+'"></input><label for="target-'+name+'-swf" class="radio inline">SWF</label>
                            </div>
                        </div>

                        <div class="control-group hx-libs">
                            <label class="control-label" for="libs-checkbox">Libraries</label>
                            <div class="controls swf-libs"></div>
                            <div class="controls js-libs"></div>
                        </div>
                    </form>
                </div>')
            .parent()
            .before('<div class="btn-group pull-right"><a href="#" class="compile-btn btn" data-loading-text="Compiling"><i class="icon-cog"></i> Run</a></div>
            <ul class="nav nav-tabs">
                <li class="active"><a href=".hx-source" data-toggle="tab">Source</a></li>
                <li><a href=".hx-options" data-toggle="tab">Options</a></li>
            </ul>')
            .parent()
            .after('<div class="compiler-out span6">
            <div class="pull-right">
                <a href="#" target="_blank" class="link-btn btn disabled"><i class="icon-share"></i> Link</a>
                <a href="#" class="fullscreen-btn btn disabled"><i class="icon-resize-full"></i> Fullscreen</a>
            </div>
            
            <ul class="nav nav-tabs">
                <li class="active"><a href=".js-output" data-toggle="tab">Output</a></li>
                <li><a href=".js-source" data-toggle="tab">JS Source</a></li>
            </ul>

            <div class="tab-content">
                <div class="tab-pane js-output active thumbnail"><iframe class="js-run" src="about:blank" name="js-run" frameborder="no" scrolling="no"></iframe></div>
                <div class="tab-pane js-source">
                    <textarea name="js-source" class="code js-source"></textarea>
                </div>
            </div>
            
            <div class="messages"></div>
        </div>');
    }
}