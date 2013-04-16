package reactivefl.disposables
{
	import reactivefl.i.IDisposable;
	
	public class SerialDisposable implements IDisposable
	{
		public var isDisposed:Boolean;
		public var current:IDisposable;
		public function SerialDisposable()
		{
		}
		public function disposable(value:IDisposable):*{
			if (!value) {
				return this.getDisposable();
			} else {
				return this.setDisposable(value);
			}
		}
		
		private function setDisposable(value:IDisposable):void
		{
			var shouldDispose:Boolean = this.isDisposed, old:IDisposable;
			if (!shouldDispose) {
				old = this.current;
				this.current = value;
			}
			if (old) {
				old.dispose();
			}
			if (shouldDispose && value) {
				value.dispose();
			}
		}
		
		private function getDisposable():*
		{
			// TODO Auto Generated method stub
			return null;
		}
		public function dispose():void
		{
			var old:IDisposable;
			if (!this.isDisposed) {
				this.isDisposed = true;
				old = this.current;
				this.current = null;
			}
			if (old) {
				old.dispose();
			}
		}
	}
}