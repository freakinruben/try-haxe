using Lambda;

class SourceTools {
	public static function indexToPos (src :String, idx:Int) : {line:Int , ch:Int} {
		var pos = {line: 0, ch: 0};
		var lines = src.split("\n");
		for (l in lines){
			if( idx >= l.length+1 ){
				idx -= l.length+1;
				pos.line++;
			}else{
				pos.ch += idx;
				break;
			}
		}
		return pos;

	}


	public static function posToIndex( src :String, pos : { line : Int, ch : Int } ){
		var char = pos.ch;
		var lines = src.split("\n");

		for( i in 0...pos.line )
			char += lines[i].length + 1;
		
		return char;
	}

	public static function getAutocompleteIndex( src : String , pos : { line : Int , ch : Int } ) : Null<Int>{
		var char = posToIndex( src , pos );
		var iniChar = char;

		while( !".".split("").has( src.charAt( char ) ) ){
			char--;
			if( char < 0 ) return null;
		}
		var skipped = src.substring(iniChar, char + 1);
		return (~/[^a-zA-Z0-9_\s]/.match(skipped)) ? null : char;
	}
}