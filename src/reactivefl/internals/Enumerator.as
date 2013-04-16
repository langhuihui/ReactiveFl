package reactivefl.internals
{
	import reactivefl.RFL;

	public class Enumerator
	{
		public var moveNext:Function;
		public var getCurrent:Function;
		public var dispose:Function;
		public function Enumerator(moveNext:Function,getCurrent:Function,dispose:Function)
		{
			this.moveNext = moveNext;
			this.getCurrent = getCurrent;
			this.dispose = dispose;
		}
		public static function create(moveNext:Function, getCurrent:Function, dispose:Function = null):Enumerator{
			var done:Boolean = false;
			dispose ||= RFL.noop;
			return new Enumerator(function ():* {
				if (done) {
					return false;
				}
				var result:* = moveNext();
				if (!result) {
					done = true;
					dispose();
				}
				return result;
			}, getCurrent, function ():Boolean {
				if (!done) {
					dispose();
					done = true;
				}
				return false;
			});
		}
	}
}