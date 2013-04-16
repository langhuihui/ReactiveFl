package reactivefl.disposables
{
	import reactivefl.RFL;
	import reactivefl.i.IDisposable;
	
	public class Disposable implements IDisposable
	{
		public var isDisposed:Boolean;
		public var action:Function;
		public function Disposable(action:Function)
		{
			this.isDisposed = false;
			this.action = action;
		}
		public static var empty:IDisposable = create(RFL.noop);
		public static function create(action:Function):Disposable{
			return new Disposable(action);
		}
		
		public function dispose():void
		{
			if (!this.isDisposed) {
				this.action();
				this.isDisposed = true;
			}
		}
	}
}