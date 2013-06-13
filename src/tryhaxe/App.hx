package tryhaxe;
class App {
#if js  public static function main () { new TryHaxeEditor("website"); }
#else   public static function main () { Api.start(); } #end
}