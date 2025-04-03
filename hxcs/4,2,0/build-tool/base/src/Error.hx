package ;

enum Error
{
	UnknownOption(name:String);
	BadFormat(optionName:String, option:String);
	InexistentInput(path:String);
	UnsupportedFeatureLevel(given:Int,expected:Int);
	NoTarget;
}
