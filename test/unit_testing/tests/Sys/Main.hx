package;

import haxe.PosInfos;

class Main {
	var a: Int = 123;
	static var returnCode = 0;

	static function assert(b: Bool, infos: Null<PosInfos> = null) {
		if(!b) {
			haxe.Log.trace("Assert failed", infos);
			returnCode = 1;
		}
	}

	public static function main() {

		trace(Sys.getEnv("ANDROID_NDK_VERSION"));

		trace(ucpp.std.FileSystem.currentPath());

		final key = "Haxe2UC++ Test Value";
		final val = "test-value=" + (Std.random(10));

		assert(Sys.getEnv(key) == null);
		Sys.putEnv(key, val);
		assert(Sys.getEnv("Haxe2UC++ Test Value") == val);
		Sys.putEnv(key, "");
		assert(Sys.getEnv(key) == null);

		if(returnCode != 0) {
			Sys.exit(returnCode);
		}
	}
}