sigma = 0.3; r = 0.05; K = 1; T = 0.25; S_max = 3; 
M=101; N = 201;

dt = T/(N-1);
dS = S_max/(M-1);
S = linspace(0, S_max, M);

V = zeros(M, N);
V(:, 1) = max(S-K, 0); % initial condition 
V(M, :) = S_max - K; % boundary condition 

for n = 2:N
   for i = 2:M-1
       C = 0.5 *(sigma*S(i)/dS)^2;
       D = r * S(i)/(2*dS);
       % central diff 
       alpha = C - D;
       beta = C + D;
       
       if alpha < 0 
          alpha = C;
          beta = C + 2*D;
       end
       
       V(i, n) = V(i, n-1) * (1-(alpha + beta + r)*dt)...
           + V(i-1, n-1)*alpha*dt + V(i+1, n-1)*beta*dt;
   end
end

S_0 = 1;
V_0 = interp1(S, V(:, N), S_0);
answer = blsprice(S_0, K, r, T, sigma);