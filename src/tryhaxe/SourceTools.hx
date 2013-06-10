package tryhaxe;
extern class SourceTools
{
	public static inline function getAutocompleteIndex( src : String , char : Int ) : Null<Int>{
		var iniChar = char;
		while(char > 0 && src.charAt(char - 1) != ".")
			char--;
		return ~/[^a-zA-Z0-9_\s]/.match(src.substring(iniChar, char)) ? null : char;
	}
}