package reactivefl.disposables
{
	import reactivefl.i.IDisposable;
	
	public class RefCountDisposable implements IDisposable
	{
		public var isDisposed:Boolean;
		public var isPrimaryDisposed:Boolean;
		public var count:int;
		public var underlyingDisposable:IDisposable;
		public function RefCountDisposable(disposable:IDisposable) {
			this.underlyingDisposable = disposable;
			this.isDisposed = false;
			this.isPrimaryDisposed = false;
			this.count = 0;
		}
		
		public function dispose():void
		{
			if (!this.isDisposed) {
				if (!this.isPrimaryDisposed) {
					this.isPrimaryDisposed = true;
					if (this.count === 0) {
						this.isDisposed = true;
						this.underlyingDisposable.dispose();
					}
				}
			}
		}
		public function getDisposable():IDisposable {
			return this.isDisposed ? Disposable.empty : new InnerDisposable(this);
		};
	}
}
import reactivefl.i.IDisposable;
import reactivefl.disposables.*;

class InnerDisposable implements IDisposable{
	private var disposable:RefCountDisposable;
	private var isInnerDisposed:Boolean;
	public function InnerDisposable(disposable:RefCountDisposable) {
		this.disposable = disposable;
		this.disposable.count++;
		this.isInnerDisposed = false;
	}
	public function dispose():void {
		if (!this.disposable.isDisposed) {
			if (!this.isInnerDisposed) {
				this.isInnerDisposed = true;
				this.disposable.count--;
				if (this.disposable.count === 0 && this.disposable.isPrimaryDisposed) {
					this.disposable.isDisposed = true;
					this.disposable.underlyingDisposable.dispose();
				}
			}
		}
	};
}