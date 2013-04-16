package reactivefl.subjects
{
	import reactivefl.i.IDisposable;
	import reactivefl.i.IObserver;
	
	public class InnerSubscription implements IDisposable
	{
		private var subject:Subject;
		private var observer:IObserver;
		public function InnerSubscription(subject:Subject,observer:IObserver)
		{
			this.subject = subject;
			this.observer = observer;
		}
		
		public function dispose():void
		{
			if (!this.subject.isDisposed && this.observer != null) {
				var idx:int = this.subject.observers.indexOf(this.observer);
				this.subject.observers.splice(idx, 1);
				this.observer = null;
			}
		}
	}
}