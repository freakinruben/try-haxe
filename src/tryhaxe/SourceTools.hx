package tryhaxe;
class SourceTools
{
	private static var autocompleteEReg = ~/[^a-zA-Z0-9_\s]/;

	public static inline function getAutocompleteIndex( src : String , char : Int ) : Null<Int>{
		var iniChar = char;
		while(char > 0 && src.charAt(char - 1) != ".")
			char--;
		return autocompleteEReg.match(src.substring(iniChar, char)) ? null : char;
	}
}