package pgr.gconsole;

import flash.errors.ArgumentError;
import flash.errors.Error;
import flash.Lib;
import pgr.gconsole.GCCommands.Register;

typedef Register = {
	var name:String;
	var alias:String;
	var object:Dynamic;
	var monitor:Bool;
	var completion:String -> Array<String>;
}
/**
 * GCCommands contains the logic used by GC to execute the commands
 * given by the user.
 *
 * @author TiagoLr ( ~~~ProG4mr~~~ )
 */
class GCCommands
{
	public static var functionsMap:Map<String, Dynamic> = new Map<String, Dynamic>();
	public static var objectsMap:Map<String, Dynamic> = new Map<String, Dynamic>();

	public function new() { }

	//---------------------------------------------------------------------------------
	//  REGISTER
	//---------------------------------------------------------------------------------
	static public function registerFunction(Function:Dynamic, alias:String) {
		
		// override existing function
		if (functionsMap.exists(alias)) {
			GC.logWarning("function " + alias + " overriden");
		}
		
		functionsMap.set(alias, Function);
	}
	
	
	static public function registerObject(object:Dynamic, alias:String) {
		if (alias == "") {
			alias = GCUtil.generateObjectAlias(object);
		}

		if (objectsMap.exists(alias)) {
			GC.logWarning("object " + alias + " overriden.");
		}

		objectsMap.set(alias, object);
	}
	//---------------------------------------------------------------------------------
	//  UNREGISTER
	//---------------------------------------------------------------------------------
	public static function unregisterFunction(alias:String):Bool {
		if (functionsMap.exists(alias)) {
			functionsMap.remove(alias);
			return true;
		}
		return false;
	}
	
	public static function unregisterObject(alias:String):Bool {
		if (objectsMap.exists(alias)) {
			objectsMap.remove(alias);
			return true;
		}
		return false;
	}
	
	
	public static function clearRegistry() {
		functionsMap  = new Map<String, Dynamic>();
		objectsMap	= new Map<String, Dynamic>();
	}

	//---------------------------------------------------------------------------------
	//  RUNTIME COMMANDS
	//---------------------------------------------------------------------------------
	public static function showHelp() {
		var output : String = "";
		output += '\n';
		output += "Type \"COMMANDS\" to view availible commands.\n";
		output += "Use 'CTRL' + 'SPACE' for AUTO-COMPLETE .\n";
		output += "Use 'PAGEUP' or 'PAGEDOWN' to scroll this console text.\n";
		output += "Use 'UP' or 'DOWN' keys to view recent commands history.\n";
		output += "Use 'CTRL' + 'SPACE' for AUTOCOMPLETE.\n";
		GC.logInfo(output);
	}

	
	public static function showCommands() {
		var output : String = "";
		output += '\n';
		output += "CLEAR                       clears console view.\n";
		output += "HELP                        shows help menu.\n";
		output += "MONITOR                     toggles monitor on or off.\n";
		output += "PROFILER                    toggles profiler on or off.\n";
		output += "FUNCS                       lists availible functions.\n";
		output += "OBJS                        lists availible objects.\n";
		output += "SET [field] [value]     assigns value to variable.\n";
		output += "PRINT [field]    	   prints field.\n";
		output += "CALL [function] [args]*     calls function.\n";
		
		GC.logInfo(output);
	}

	/**
	 * Safely calls a function via Reflection with an array of dynamic arguments. Prevents a crash from happening
	 * if there are too many Arguments (the additional ones are removed and the function is called anyway) or too few
	 * 
	 * @param	FunctionAlias	The reference to the function to call.
	 * @param	Args			An array of arguments.
	 * 
	 */
	public static function callFunction(Args:Array<String>) {
		var object:Dynamic = null;
		var funcName:String = "";
		
		if (Args.length == 0) {
			GC.logError("incorrect number of arguments");
			return;
		}
		
		// search registry for existing function.
		var Function = getFunction(Args[0]);
		if (Function == null) {
			
			// function not found, get function name from input.
			if (Args[0].split('.').length > 1) {
				var objArgs = Args[0].split('.');
				funcName = objArgs.pop(); // remove function call
				object = GCUtil.lookForObject(objArgs);
				if (object == null) {
					GC.logError("function not found");
					return;
				}
			} else {
				GC.logError("function not found");
				return;
			}
		}
		
		// call function.
		Args.shift();
		try {
			if (object == null) {
				Reflect.callMethod(null, Function, Args);
			} else {
				Reflect.callMethod(object, Reflect.getProperty(object, funcName), Args);
			}
			GC.logConfirmation("done");
		}
		catch (e:ArgumentError) {
			if (e.errorID == 1063) {
				GC.logError("incorrect number of arguments");
			}
		}
		catch (e:Error) {
			GC.logError("function not found");
		} catch (e:String) {
			GC.logError("failed to call function");
		}
	}
	
	static public function printProperty(args:Array<String>) {
		
		if (args.length == 1) {
			args.push(null);
		} else {
			args[1] = null;
		}
		
		setVariable(args, true);
	}
	
	static public function setVariable(args:Array<String>, print:Bool = true) {
		var object:Dynamic = null;
		var varName:String = "";
		
		if (args.length < 2) {
			GC.logError("incorrect number of arguments");
			return;
		}
		
		// parse input, retreive object and variable name.
		if (args[0].split('.').length > 0) {
			var objArgs = args[0].split('.');
			varName = objArgs.pop(); // remove function call
			object = GCUtil.lookForObject(objArgs);
			if (object == null) {
				GC.logError("object not found");
				return;
			}
		} else {
			GC.logError("property not found");
			return;
		}
		
		try {
			
			if (args[1] != null) {
				
				var value:Dynamic;
				if (args[1] == "true") // bool
					value = true;
				else 
				if (args[1] == "false") // bool
					value = false;
				else 
				if (Std.parseInt(args[1]) != null) { // float or int
					var asInt = Std.parseInt(args[1]);
					var asFloat = Std.parseFloat(args[1]);
					
					if (asInt == asFloat && !Math.isNaN(asFloat)) {
						value = asInt;
					} else {
						value = asFloat;
					}
				} else {
					value = args[1]; // string
				}
				
				Reflect.setProperty(object, varName, value);
			}
			
			if (print) {
				var p = Reflect.getProperty(object, varName);
				GC.log(p);
			} else {
				GC.logConfirmation("done");
			}
			
		} catch (e:Error) {
			GC.logError("failed to set property");
			return;
		} catch (e:String) {
			GC.logError("failed to set property");
			return;
		}
	}
	

	public static function listFunctions() {
		var list = "";
		for (key in functionsMap.keys()) {
			list += key + '\n'; 
		}

		if (list.toString() == "") {
			GC.logInfo("no functions registered.");
		} else {
			GC.logConfirmation(list);
		}
	}

	
	public static function listObjects()
	{
		var list = "";
		for (key in objectsMap.keys())  {
			list += key + '\n'; 
		}

		if (list.toString() == '') {
			GC.logInfo("no objects registered.");
		} else 
			GC.logConfirmation(list);
	}

	
	static public function getFunction(alias:String):Register {
		if (functionsMap.exists(alias))
			return functionsMap.get(alias);
		return null;
	}

	
	static public function getObject(alias:String) {
		if (objectsMap.exists(alias)) {
			return objectsMap.get(alias);
		}
		return null;
	}
	
	/** 
	 * Takes a string and filters out everything but the digits.
	 * 
	 * @param 	Input	The input string
	 * @return 	The output string, digits-only
	 */
	static function filterDigits(Input:String):String
	{
		var output = new StringBuf();
		for (i in 0...Input.length) {
			var c = Input.charCodeAt(i);
			if (c >= '0'.code && c <= '9'.code) {
				output.addChar(c);
			}
		}
		return output.toString();
	}
	
}
