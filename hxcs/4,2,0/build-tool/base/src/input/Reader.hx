package input;
import haxe.io.Eof;
import haxe.io.Input;
import input.Error;
import input.Data;

using StringTools;

class Reader
{
	var i : Input;
	var lineNum : Int;
	var cmd : CommandLine;

	public function new(cmd,i)
	{
		this.i = i;
		this.lineNum = 0;
		this.cmd = cmd;
	}

	private function readLine()
	{
		lineNum++;
		return i.readLine();
	}

	private function readSection(name:String, ret:Data)
	{
		var i = i;
		function getLine()
		{
			var line = readLine().ltrim();
			if (line.startsWith("end "))
			{
				var section = line.substr(4).trim();
				if (section != name)
					throw UnmatchedSection(section, name, lineNum);

				return null;
			}
			return line;
		}

		switch(name)
		{
		case "defines":
			var line;
			while ( (line = getLine()) != null)
			{
				ret.defines.set(line.rtrim(), true);
			}
		case "defines_data":
			var line;
			while ( (line = getLine()) != null)
			{
				var index = line.indexOf("=");
				var key = line.substring(0, index).rtrim();
				var value = line.substring(index + 1, line.length).ltrim();
				ret.definesData.set(key, value);
			}
		case "libs":
			var line;
			while ( (line = getLine()) != null)
			{
				ret.libs.push(line.rtrim());
			}
		case "modules":
			var line, lastPath = null, lastArr:Array<ModuleType> = null;
			while ( (line = getLine()) != null)
			{
				if (line.startsWith("M "))
				{
					if (lastPath != null && lastArr.length > 0)
						ret.modules.push( { path: lastPath, types:lastArr } );

					lastPath = line.substr(2);
					lastArr = [];
				} else if (line.startsWith("C ")) {
					lastArr.push(MClass(line.substr(2)));
				} else if (line.startsWith("E ")) {
					lastArr.push(MEnum(line.substr(2)));
				}
			}
			if (lastPath != null && lastArr.length > 0)
				ret.modules.push( { path: lastPath, types:lastArr } );
		case "resources":
			var line;
			while ( (line = getLine()) != null)
			{
				ret.resources.push(line.ltrim());
			}
		case "main":
			ret.main = getLine();
			var line = getLine();
			if (line != null)
				throw Unexpected(line, lineNum);
		case "opts":
			var line = null;
			while ( (line = getLine()) != null )
			{
				ret.opts.push(line);
			}
		case unk:
			var toolName = cmd.name;
			Sys.stderr().writeString('WARNING: The option $unk was passed to the build tool and wasn\'t recognized. It is recommended that you update the $toolName tool\n');
			var line = getLine();
			while (line != null) line = getLine();
		}
	}

	public function read():Data
	{
		var ret =
		{
			baseDir: null,
			defines: new Map(),
			definesData: new Map(),
			modules: [],
			main: null,
			resources: [],
			libs: [],
			opts: []
		};

		var i = i;
		try
		{
			ret.baseDir = readLine();
			while (true)
			{
				var line = readLine().ltrim();
				if (line.startsWith("begin "))
				{
					var section = line.substr(6).trim();
					readSection(section, ret);
				}
			}
		}

		catch (e:Eof)
		{

		}

		//some versions may still contain the bug that adds multiple times the same module
		var unique = new Map();
		var newMods = [];
		for (r in ret.modules)
		{
			if (!unique.exists(r.path))
			{
				newMods.push(r);
				unique.set(r.path, true);
			}
		}
		ret.modules = newMods;

		return ret;
	}

}
