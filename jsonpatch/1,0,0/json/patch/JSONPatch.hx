package json.patch;

import json.pointer.JSONPointer;
import json.JSONData;
import json.util.TypeUtil;
import json.path.JSONPath;

using StringTools;

class JSONPatch {

    /**
     * For the given JSON data, apply all the provided JSONPatch operations.
     * @param data A JSON data object. You can pass `Dynamic` or `Array<Dynamic>` here.
     * @param patch An array of JSONPatch operations to perform.
     * @see https://datatracker.ietf.org/doc/rfc6902/
     * @return The resulting JSON data.
     */
    public static function applyPatches(data:JSONData, patch:Array<JSONData>):JSONData {
        if (data == null || patch == null) return null;
        if (patch.length == 0) return data;
        
        var result:JSONData = cast data.copy(); // Explicitly cast the result of data.copy()
        
        var firstOperation = true;

        for (operation in patch) {
            result = JSONPatch.applyOperation(result, operation);
        }

        return result;
    }

    /**
     * For the given JSON data, apply a single JSONPatch operation.
     * @param data A JSON data object. You can pass `Dynamic` or `Array<Dynamic>` here.
     * @param patch A JSONPatch operation to perform.
     * @see https://datatracker.ietf.org/doc/rfc6902/
     * @return The resulting JSON data.
     */
    public static function applyOperation(data:JSONData, operation:JSONData):JSONData {
        if (operation == null) return data;

        var result:JSONData = cast data.copy(); // Explicitly cast the result of data.copy()
        var op = operation.get('op');

        if (op == "add") {
            var value:Dynamic = getOperationValue(operation, 'value');
            result = applyOperation_add(result, operation.get('path'), value);
        } else if (op == "remove") {
            result = applyOperation_remove(result, operation.get('path'));
        } else if (op == "replace") {
            var replaceValue:Dynamic = getOperationValue(operation, 'value');
            result = applyOperation_replace(result, operation.get('path'), replaceValue);
        } else if (op == "move") {
            result = applyOperation_move(result, operation.get('from'), operation.get('path'));
        } else if (op == "copy") {
            result = applyOperation_copy(result, operation.get('from'), operation.get('path'));
        } else if (op == "test") {
            var testValue:Dynamic = getOperationValue(operation, 'value');
            result = applyOperation_test(result, operation.get('path'), testValue);
        } else {
            throw 'Unsupported operation "$op", expected one of "test", "add", "replace", "remove", "move", "copy"';
        }

        return result;
    }

    static function getOperationValue(operation:JSONData, key:String):Dynamic {
        // Helper function to get the value of an operation or return NoValue
        if (operation.exists(key)) {
            return operation.get(key);
        } else {
            return NoValue;
        }
    }

    static function getParentPath(path:String):String {
        if (path == null || path == "") throw 'Invalid path';
        var lastSlash = path.lastIndexOf('/');
        if (lastSlash == -1) return "";
        return path.substr(0, lastSlash);
    }

    static function getLastPathSegment(path:String):String {
        if (path == null || path == "") throw 'Invalid path';
        var lastSlash = path.lastIndexOf('/');
        if (lastSlash == -1) return path;
        return path.substr(lastSlash + 1);
    }

    static function resolve(data:Dynamic, path:String):Dynamic {
        if (path == null || path == "") return data;
        var segments = path.split('/');
        var current = data;
        for (segment in segments) {
            if (segment == "") continue;
            // Convert segment to Int if current is an array
            if (segment == "-") {
                if (Std.is(current, Array)) {
                    current = current[current.length - 1];
                } else {
                    throw 'Invalid array index: $segment';
                }
            } else if (segment == "*") {
                if (Std.is(current, Array)) {
                    current = current;
                } else {
                    throw 'Invalid wildcard segment: $segment';
                }
            } else if (TypeUtil.isString(segment)) {
                segment = StringTools.urlDecode(segment);
            }

            if (Std.is(current, Array)) {
                var index = Std.parseInt(segment);
                if (index == null) throw 'Invalid array index: $segment'; // Handle null case for Std.parseInt
                current = current[index];
            } else {
                if (!Reflect.hasField(current, segment)) throw 'Invalid path segment: $segment';
                current = Reflect.field(current, segment);
            }
        }
        return current;
    }

    static function applyOperation_add(data:JSONData, path:String, value:Dynamic):JSONData {
        if (path == null) throw 'path is required';
        if (value == NoValue) throw 'value is required'; // Fix for NoValue.NoValue

        var targetPaths = parsePaths(path, data);

        for (targetPath in targetPaths) {
            try {
                var parentPath = getParentPath(targetPath);
                var key = getLastPathSegment(targetPath);
                var parent = resolve(data, parentPath);
                if (parent == null) throw 'add to a non-existent target';

                // Handle array indices
                if (Std.is(parent, Array)) {
                    var index = Std.parseInt(key);
                    if (index == null) throw 'Invalid array index: $key'; // Ensure index is valid
                    parent.insert(index, value);
                } else {
                    parent[key] = value;
                }
            } catch (e) {
                throw e;
            }
        }

        return data;
    }

    static function applyOperation_remove(data:JSONData, path:String):JSONData {
        if (path == null) throw 'path is required';

        var targetPaths = parsePaths(path, data);

        for (targetPath in targetPaths) {
            var parentPath = getParentPath(targetPath);
            var key = getLastPathSegment(targetPath);
            var parent = resolve(data, parentPath);
            if (parent == null) throw 'remove target $targetPath does not exist';

            // Handle array indices
            if (Std.is(parent, Array)) {
                var index = Std.parseInt(key);
                if (index == null) throw 'Invalid array index: $key'; // Ensure index is valid
                parent.splice(index, 1);
            } else if (Reflect.hasField(parent, key)) {
                Reflect.deleteField(parent, key);
            } else {
                throw 'remove target $targetPath does not exist';
            }
        }

        return data;
    }

    static function applyOperation_replace(data:JSONData, path:String, value:Dynamic):JSONData {
        if (path == null) throw 'path is required';
        if (value == NoValue) throw 'value is required'; // Fix for NoValue.NoValue

        var targetPaths = parsePaths(path, data);

        for (targetPath in targetPaths) {
            var parentPath = getParentPath(targetPath);
            var key = getLastPathSegment(targetPath);
            var parent = resolve(data, parentPath);
            if (parent == null) throw 'replace target $targetPath does not exist';

            // Handle array indices
            if (Std.is(parent, Array)) {
                var index = Std.parseInt(key);
                if (index == null) throw 'Invalid array index: $key'; // Ensure index is valid
                parent[index] = value;
            } else {
                parent[key] = value;
            }
        }

        return data;
    }

    static function applyOperation_move(data:JSONData, from:String, path:String):JSONData {
        if (path == null) throw 'path is required';
        if (from == null) throw 'from is required';

        var targetFromPaths = parsePaths(from, data);
        var targetPaths = parsePaths(path, data);

        for (targetFromPath in targetFromPaths) {
            var parentFromPath = getParentPath(targetFromPath);
            var keyFrom = getLastPathSegment(targetFromPath);
            var parentFrom = resolve(data, parentFromPath);
            if (parentFrom == null) throw 'no element at from path $targetFromPath';

            // Handle array indices
            var value:Dynamic;
            if (Std.is(parentFrom, Array)) {
                var indexFrom = Std.parseInt(keyFrom);
                if (indexFrom == null) throw 'Invalid array index: $keyFrom'; // Ensure index is valid
                value = parentFrom[indexFrom];
                parentFrom.splice(indexFrom, 1);
            } else {
                value = Reflect.field(parentFrom, keyFrom);
                Reflect.deleteField(parentFrom, keyFrom);
            }

            for (targetPath in targetPaths) {
                var parentPath = getParentPath(targetPath);
                var key = getLastPathSegment(targetPath);
                var parent = resolve(data, parentPath);
                if (parent == null) throw 'add to a non-existent target';

                // Handle array indices
                if (Std.is(parent, Array)) {
                    var index = Std.parseInt(key);
                    if (index == null) throw 'Invalid array index: $key'; // Ensure index is valid
                    parent.insert(index, value);
                } else {
                    parent[key] = value;
                }
            }
        }

        return data;
    }

    static function applyOperation_copy(data:JSONData, from:String, path:String):JSONData {
        if (path == null) throw 'path is required';
        if (from == null) throw 'from is required';

        var targetFromPaths = parsePaths(from, data);
        var targetPaths = parsePaths(path, data);

        for (targetFromPath in targetFromPaths) {
            var parentFromPath = getParentPath(targetFromPath);
            var keyFrom = getLastPathSegment(targetFromPath);
            var parentFrom = resolve(data, parentFromPath);
            if (parentFrom == null || !Reflect.hasField(parentFrom, keyFrom)) {
                throw 'no element at from path $targetFromPath';
            }

            var value = Reflect.field(parentFrom, keyFrom);

            for (targetPath in targetPaths) {
                var parentPath = getParentPath(targetPath);
                var key = getLastPathSegment(targetPath);
                var parent = resolve(data, parentPath);
                if (parent == null) throw 'add to a non-existent target';
                parent[key] = value;
            }
        }

        return data;
    }

    static function applyOperation_test(data:JSONData, path:String, expected:Dynamic):JSONData {
        if (path == null) throw 'path is required';
        if (expected == NoValue) throw 'value is required'; // Fix for NoValue.NoValue

        var targetPaths = parsePaths(path, data);

        for (targetPath in targetPaths) {
            var parentPath = getParentPath(targetPath);
            var key = getLastPathSegment(targetPath);
            var parent = resolve(data, parentPath);
            if (parent == null || !Reflect.hasField(parent, key)) {
                throw 'test failed, target not found';
            }

            var actual = Reflect.field(parent, key);
            if (!thx.Dynamics.equals(actual, expected)) {
                throw 'test failed, values ($actual =/= $expected) not equivalent';
            }
        }

        return data;
    }

    static function parsePaths(path:String, data:JSONData):Array<String> {
        // Parse a JSONPath string
        if (path.startsWith('$')) return JSONPath.queryPaths(path, data);

        // Parse a JSONPointer string.
        return [JSONPointer.toJSONPath(path)];
    }
}

enum NoValue {
    NoValue;
}