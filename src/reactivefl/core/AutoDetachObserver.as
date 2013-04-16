package reactivefl.core
{
	import reactivefl.disposables.SingleAssignmentDisposable;
	import reactivefl.i.IDisposable;
	import reactivefl.i.IObserver;

	public class AutoDetachObserver extends AbstractObserver
	{
		private var observer:IObserver;
		private var m:SingleAssignmentDisposable;
		public function AutoDetachObserver(observer:IObserver)
		{
			super();
			this.observer = observer;
			this.m = new SingleAssignmentDisposable();
		}
		override protected function next(value:*):void{
			var noError:Boolean = false;
			try {
				this.observer.onNext(value);
				noError = true;
			} catch (e:Error) { 
				throw e;                
			} finally {
				if (!noError) {
					this.dispose();
				}
			}
		}
		override protected function error(error:Error):void{
			try {
				this.observer.onError(error);
			} catch (e:Error) { 
				throw e;                
			} finally {
				this.dispose();
			}
		}
		override protected function completed():void{
			try {
				this.observer.onCompleted();
			} catch (e:Error) { 
				throw e;                
			} finally {
				this.dispose();
			}
		}
		public function disposable(value:IDisposable):IDisposable{
			return this.m.disposable(value);
		}
		override public function dispose():void{
			super.dispose();
			m.dispose();
		}
	}
}