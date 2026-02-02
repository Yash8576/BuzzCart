import * as React from "react";
import { cn } from "../../lib/utils";

const Sheet = ({ children, ...props }) => {
  return <div {...props}>{children}</div>;
};

const SheetTrigger = React.forwardRef(({ className, children, ...props }, ref) => {
  return (
    <button ref={ref} className={cn(className)} {...props}>
      {children}
    </button>
  );
});
SheetTrigger.displayName = "SheetTrigger";

const SheetContent = React.forwardRef(({ className, children, ...props }, ref) => {
  return (
    <div
      ref={ref}
      className={cn(
        "fixed inset-y-0 right-0 z-50 h-full w-3/4 gap-4 border-l bg-background p-6 shadow-lg transition ease-in-out data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:duration-300 data-[state=open]:duration-500 sm:max-w-sm",
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
});
SheetContent.displayName = "SheetContent";

export { Sheet, SheetTrigger, SheetContent };
