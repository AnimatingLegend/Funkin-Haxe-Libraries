package ;

class CommandLine
{
	public var name(default,null):String;
	//Required: Where to build
	public var target:String;
	public var version:Int;
	public var output:Null<String>;
	public var featureLevel:Int;

	public function new(name:String)
	{
		this.name = name;
		this.featureLevel = 0;
	}

	public function process(args:Array<String>, arg:Int = 0)
	{
		var len = args.length;
		this.target = args[arg++];
		while (arg < len)
		{
			switch(args[arg++])
			{
			case "--haxe-version":
				var ver = Std.parseInt(args[arg++]);
				if (ver == null)
					throw Error.BadFormat("--haxe-version", args[arg - 1]);
				this.version = ver;
			case "--feature-level":
				var ver = Std.parseInt(args[arg++]);
				if (ver == null)
					throw Error.BadFormat("--feature-level", args[arg - 1]);
				this.featureLevel = ver;
			case "--out":
				this.output = args[arg++];
				if (output == null)
					throw Error.BadFormat("--out", null);
			default:
				throw Error.UnknownOption(args[arg - 1]);
			}
		}
	}

	public function getOptions()
	{
		return
		' Usage : haxelib run '+ name +' buildFile.txt [?... options]\n' +
		' Options :\n' +
		'  --haxe-version <version> : sets what baseline haxe version was it compiled with\n' +
		'  --feature-level <level> : sets the feature level needed to compile the buildFile. Defaults to 0\n' +
		'  --out <filename> : sets the output file path\n';
	}

}
