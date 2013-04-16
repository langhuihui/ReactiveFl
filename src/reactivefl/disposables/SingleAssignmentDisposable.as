package reactivefl.disposables
{
	import reactivefl.i.IDisposable;

	public class SingleAssignmentDisposable implements IDisposable
	{
		public var isDisposed:Boolean;
		public var current:IDisposable;
		public function SingleAssignmentDisposable()
		{
		}
		public function disposable(value:IDisposable):IDisposable{
			return !value ? getDisposable() : setDisposable(value);
		}
		public function dispose():void{
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
		public function setDisposable(value:IDisposable):IDisposable
		{
			if (this.current) {
				throw new Error('Disposable has already been assigned');
			}
			var shouldDispose:Boolean = this.isDisposed;
			if (!shouldDispose) {
				this.current = value;
			}
			if (shouldDispose && value) {
				value.dispose();
			}
			return value;
		}
		
		public function getDisposable():IDisposable
		{
			return current;
		}
		
	}
}