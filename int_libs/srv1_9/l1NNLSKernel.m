function x=l1NNLSKernel(AtA,Atb,btb,lambda,AtAInv,option)
% Newton's algorithm to solve the kernel NNLS problem:
% min f(x)=1/2||phi(b)-phi(A)x||_2^2 s.t. x>=0 where x is of size n
% by 1
% AtA: n by n matrix, the inner product or kernel matrix of A
% Atb: n by 1 matrix, the inner product or kernel matrix between A and b
% btb: scalar, b'*b
% AtAInv: n by n matrix, the inverse of AtA
% option
% x, n by 1 column vector, the sparse coefficient
% Yifeng Li
% Feb. 07, 2011

if nargin<6
    option=[];
end
optionDefault.NewtonMaxIter=100;
optionDefault.tol=1e-4;
optionDefault.tIni=1/lambda; % the initial value of t
optionDefault.updatetmu=2;
optionDefault.alpha=0.01; % for backtracking line search
optionDefault.beta=0.5; % for backtracking line search
optionDefault.lineSearchMaxIter=5000;
optionDefault.smin=0.5;
optionDefault.pcgTol=1e-3;
optionDefault.maxit=100;
option=mergeOption(option,optionDefault);
nVar=size(AtA,1);
% initialize x and u
x=AtAInv*Atb;%zeros(nVar,1);%AtAInv*Atb;
x(x<=0)=1e-8;
dualGap=Inf;
i=0;
t=option.tIni;
dualVal=-Inf;
while dualGap>=option.tol && i+1<=option.NewtonMaxIter
    i=i+1;
%     fprintf('The %d-th iteration of Newtons method for l1NNLS ...\n',i);
   % compute gradient and hessian, and then the update deltaxu
   g=t*(AtA*x-Atb + lambda*ones(nVar,1)) - 1./x;
   H=t*AtA+ diag(1./(x.*x));
%    deltax=-(H\g);
   deltax=-((H+2^(-32)*eye(nVar))\g);
%     normg   = norm(g);
%     pcgtol  = min(1e-1,option.pcgTol*dualGap/min(1,normg));
%     M=t*diag(diag(H));
%    [deltax,flag,relres,iter,resvec]=pcg(H,-g,pcgtol,option.maxit,M);
   % search the step size of Newton's method
    % update x
   s=1;
   oldf=0.5*t*x'*AtA*x - t*Atb'*x + 0.5*t*btb + t*lambda*sum(x) -sum(log(x));
   for j=1:option.lineSearchMaxIter
       newx=x+s*deltax;
       if min(newx>0)
           newf1=0.5*t*newx'*AtA*newx - t*Atb'*newx + 0.5*t*btb + t*lambda*sum(newx) -sum(log(newx));
           newf2 = oldf + option.alpha*s*g'*deltax;
           if newf1<=newf2
               break;
           end
       else 
%            fprintf('infeasible solution\n');
       end
       s=option.beta*s;
   end
   % update (x,u) use step size s
   x=x+s*deltax;
   % compute the duality gap
   xtAtAx=x'*AtA*x;
   dualGap=xtAtAx - Atb'*x + lambda*sum(x);
%    dualVal=max(-0.5*xtAtAx+0.5*btb,dualVal)
%    primalVal=0.5*xtAtAx - Atb'*x + 0.5*btb + lambda*sum(x)
%    dualGap=dualGap/dualVal
   % update t
   if s>=option.smin
       t=max(option.updatetmu*min(nVar/dualGap,t),t);
   end
%    dualGap=dualGap/dualVal; % relative
end
% fprintf('l1NNLS via Newtons method finished.\n');
end

