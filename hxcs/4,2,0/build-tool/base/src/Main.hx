package ;

import haxe.io.Path;
import input.Reader;
import sys.FileSystem;
import sys.io.File;

/**
 * Java/C# build tool. Automatically calls the Java/C# compiler to compile the Haxe generated source
 * @author waneck
 */

class Main
{

	static inline var SUPPORTED_FEATURE_LEVEL = 1;

	static function main()
	{
		var target = null;
		var name = #if target_cs 'hxcs' #else 'hxjava' #end;
		try
		{
			//pre-process args:
			var cmd = new CommandLine(name);
			var args = Sys.args();
			var last = args[args.length - 1];

			var cwd = Sys.getCwd();
			if (last != null && FileSystem.exists(last = last.substr(0,last.length-1))) //was called from haxelib
			{
				args.pop();
				Sys.setCwd(cwd = last);
			}

			//get options
			cmd.process(args);
			if (cmd.target == null)
				throw Error.NoTarget;
			if (cmd.featureLevel > SUPPORTED_FEATURE_LEVEL)
				throw Error.UnsupportedFeatureLevel(cmd.featureLevel,SUPPORTED_FEATURE_LEVEL);

			//read input
			if (!FileSystem.exists(target = cmd.target))
				throw Error.InexistentInput(target);
			var f = File.read(target);
			var data = new Reader(cmd,f).read();
			f.close();

			data.baseDir = Tools.addPath(cwd, data.baseDir);
			Sys.setCwd(Path.directory(Tools.addPath(cwd, cmd.target)));

			//compile
			#if !target_cs
			new compiler.java.Javac(cmd).compile(data);
			#else
			new compiler.cs.CSharpCompiler(cmd).compile(data);
			#end
		}

		catch (e:Error)
		{
			switch(e)
			{
			case UnsupportedFeatureLevel(given,expected):
				println('You have an outdated version of the $name tool. Please update it by running `haxelib update $name` or if you\'re using a git build, update the tool to use its development directory.\nUnsupported feature level $given. This tool only supports up to feature level $expected');
			case UnknownOption(name):
				println("Unknown command-line option " + name);
			case BadFormat(optionName, option):
				println("Unrecognized '" + option + "' value for " + optionName);
			case InexistentInput(path):
				println("File at path " + path + " not found");
			case NoTarget:
				println("No target defined");
			}

			Sys.println(new CommandLine(#if target_cs "hxcs" #else "hxjava" #end).getOptions());

			Sys.exit(1);
		}

		catch (e:input.Error)
		{
			println("Error when reading input file");
			switch(e)
			{
			case UnmatchedSection(name, expected, lineNum):
				println(target + " : line " + lineNum + " : Unmatched end section. Expected " + expected + ", got " + name);
			case Unexpected(string, lineNum):
				println(target + " : line " + lineNum + " : Unexpected " + string);
			}
			Sys.exit(2);
		}

		catch (e:compiler.Error)
		{
			println("Compilation error");
			switch(e)
			{
			case CompilerNotFound:
				#if target_java
				println("Java compiler not found. Please make sure JDK is installed. If it is, please add an environment variable called JAVA_HOME that points to the JDK install location or add the bin subfolder to your PATH environment.");
				#elseif target_cs
				println("C# compiler not found. Please make sure either Visual Studio or mono is installed or they are reachable by their path");
				#else
				println("Native compiler not found. Please make sure it is installed and its path is set correctly");
				#end
			case BuildFailed:
				println("Native compilation failed");
			}
			Sys.exit(3);
		}

	}

	private static function println(str:String)
	{
		Sys.stderr().writeString(str+'\n');
	}
}
