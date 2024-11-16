# Intelligent-speech-processing
​
大部分参考这篇文章（实践发现理论加代码是最好理解的）ADPCM(自适应差分脉冲编码调制)的原理和计算 - Milton - 博客园 (cnblogs.com)

1、假设输入音频数据的每个采样点是16bit数据，编码后传输的采样点也是16bit.如果用-律非均匀量化编码与解码后单纯地改变每个样本点的量化比特数（4bit），这样传输的时候数据也是4bit,可以理解为把编码后的数据（16bit）的2^16份分成2^4份，把数值映射到2^4个区间，减小数据精度来压缩数据。如果用ADPCM编码，则是对相邻采样点的差值进行编码，虽然差值范围还是在-(2^16)/2~(2^16)/2区间，也需要16bit传输，但是通过步长编码(根据人的听觉特性，有特殊国际标准，我的理解是差值越大，人耳相对不是很敏感，所以可以压缩多点)把差值索引（index）的差值压缩到了4bit,传输的时候一个采样点用4bit代表就行。

2、两个码表, 一个是差值步长码表（89个值）, 一个是差值步长下标变化量码表（2^4个，对应4bit的code编码）



应该是有很多标准，可能还要结合实际输入数据范围和编码的bit大小

3、4bit编码的伪代码

        % Calculate the B3,B2,B1,B0 step by step following the References-1 as
        % follows:
        %     let B3 = B2 = B1 = B0 = 0 
        %     if (d(n) < 0)    
        %         then B3 = 1 
        %     d(n) = ABS(d(n)) 
        %     if (d(n) >= ss(n))    
        %         then B2 = 1 and d(n) = d(n) - ss(n) 
        %     if (d(n) >= ss(n) / 2)    
        %         then B1 = 1 and d(n) = d(n) - ss(n) / 2 
        %     if (d(n) >= ss(n) / 4)    
        %         then B0 = 1 L(n) = (10002 * B3) + (1002 * B2) + (102 * B1) + B0   
        
这个是matlab官网的ADPCM编码（好像没有解码）小工具的说明书截图：

工具代码包下载：

https://www.mathworks.com/matlabcentral/fileexchange/45310-adpcm



4、加上固定的1/8步长,如下，在用fix函数取整数的时候，对小数进行了忽略，所以需要精度补偿。

按照伪代码写的：

        tmpstep=step;
        diffq=fix(step/8);
        if diff >= tmpstep  
            B2(i) = 1 ;
            diff=diff-tmpstep;
            diffq=diffq+step;
        end
        tmpstep=fix(tmpstep/2);
        if diff >= tmpstep
            B1(i) = 1 ;
            diff=diff-tmpstep;
            diffq=diffq+fix(step/2);
        end
        tmpstep=fix(tmpstep/2);
        if diff >= tmpstep
            B0(i) = 1 ;
            diffq=diffq+fix(step/4);
        end
前面以为写错了，后面发现好像前面这样写好像也可以：

        if diff <=ss(index+1)/4
            B2(i) = 0; B1(i) = 0; B0(i) = 0;
        elseif diff > ss(index+1)/4 && diff <= ss(index+1)/2
            B2(i) = 0; B1(i) = 0; B0(i) = 1;
        elseif diff > ss(index+1)/2 && diff <= ss(index+1)*3/4
            B2(i) = 0; B1(i) = 1; B0(i) = 0;
        elseif diff > ss(index+1)*3/4 && diff <= ss(index+1)
            B2(i) = 0; B1(i) = 1; B0(i) = 1;
        elseif diff > ss(index+1) && diff <= ss(index+1)*5/4
            B2(i) = 1; B1(i) = 0; B0(i) = 0;
        elseif diff > ss(index+1)*5/4 && diff <= ss(index+1)*3/2
            B2(i) = 1; B1(i) = 0; B0(i) = 1;
        elseif diff > ss(index+1)*3/2 && diff <= ss(index+1)*7/4
            B2(i) = 1; B1(i) = 1; B0(i) = 0;
        elseif diff > ss(index+1)*7/4
            B2(i) = 1; B1(i) = 1; B0(i) = 1;
        end
    
        L = 8*B3(i) + 4*B2(i) + 2*B1(i) + B0(i); % Convert the binary number "(B3B2B1B0)_2" to decimal number L as output
        out(i) = L;
        
        % Get the data-increment= based on step_sizes_table and index
        diffq = fix(ss(index+1)/8) + fix(B0(i)*ss(index+1)/4) + fix(B1(i)*ss(index+1)/2) + fix(B2(i)*ss(index+1));
        diffq = (-1)^B3(i)*diffq;
        pre_data = pre_data + diffq; % Get the predicted data according to the data-increment
        index = index + Ml_values_table(4*B2(i) + 2*B1(i) + 1*B0(i) + 1);  % Convert the binary number "(B2B1B0)_2" to decimal number
    
5、编码过程

function code = adpcm_encoder(x)    
    Ml_values_table = [-1,-1,-1,-1,2,4,6,8,-1,-1,-1,-1,2,4,6,8];
    step_sizes_table = [7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796, 876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767];    
    ss = step_sizes_table;
    
    % Initialization,index 存储的是上一次预测的差值步长下标, 通过查表可以得到步长,matlab索引值最小是1，不是0
    index = 1;
    % predsample 存储的是上一个解码值, 解码还原时产生的就是这个值
    pre_data = 0;
    B0=zeros(size(x));
    B1=zeros(size(x)); 
    B2=zeros(size(x)); 
    B3=zeros(size(x));
    %编码后的4bit数组code
    code = zeros(size(x));
    
    for i = 1:length(x)
        current_data = x(i);                % input current data
        diff = current_data - pre_data;     % calculate data-increment
        %当前步长
        step = ss(index);
    
        % Calculate the B3,B2,B1,B0 step by step following the References-1 as
        % follows:
        %     let B3 = B2 = B1 = B0 = 0 
        %     if (d(n) < 0)    
        %         then B3 = 1 
        %     d(n) = ABS(d(n)) 
        %     if (d(n) >= ss(n))    
        %         then B2 = 1 and d(n) = d(n) - ss(n) 
        %     if (d(n) >= ss(n) / 2)    
        %         then B1 = 1 and d(n) = d(n) - ss(n) / 2 
        %     if (d(n) >= ss(n) / 4)    
        %         then B0 = 1 L(n) = (10002 * B3) + (1002 * B2) + (102 * B1) + B0   
        
        % 负号编码
        if diff<0
            diff = abs(diff); 
            B3(i) = 1; 
        end

        tmpstep=step;
        diffq=fix(step/8);
        if diff >= tmpstep  
            B2(i) = 1 ;
            diff=diff-tmpstep;
            diffq=diffq+step;
        end
        tmpstep=fix(tmpstep/2);
        if diff >= tmpstep
            B1(i) = 1 ;
            diff=diff-tmpstep;
            diffq=diffq+fix(step/2);
        end
        tmpstep=fix(tmpstep/2);
        if diff >= tmpstep
            B0(i) = 1 ;
            diffq=diffq+fix(step/4);
        end


        L = 8*B3(i) + 4*B2(i) + 2*B1(i) + B0(i); % Convert the binary number "(B3B2B1B0)_2" to decimal number L as output
        code(i) = L;
        
        % % Get the data-increment= based on step_sizes_table and index
        diffq = (-1)^B3(i)*diffq;
        pre_data = pre_data + diffq; % Get the predicted data according to the data-increment
        
        index = index + Ml_values_table(L+1);  % Convert the binary number "(B2B1B0)_2" to decimal number
        if (pre_data>32767)
            pre_data=32767;
        elseif (pre_data<-32767)
            pre_data=-32767;     % Limit the index in the range of step_sizes_table:(0,49)
        end      
        if (index<=0)
            index=1;
        elseif (index>=89)
            index=89;     % Limit the index in the range of step_sizes_table:(0,49)
        end   
    end
end
6、解码过程

function [out] = decoder(x)
    Ml_values_table = [-1,-1,-1,-1,2,4,6,8,-1,-1,-1,-1,2,4,6,8];
    step_sizes_table = [7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796, 876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767];    
    ss = step_sizes_table;
    
    out = zeros(size(x));
    % Initialization,index 存储的是上一次预测的差值步长下标, 通过查表可以得到步长
    index = 1;
    % predsample 存储的是上一个解码值, 解码还原时产生的就是这个值
    pre_data = 0;
    % 


    for i = 1:length(x)
        data = x(i);                % input current 4 bit data
        %当前步长
        step = ss(index);
        diffq = fix(step /8);
        
        % 将整数转换为二进制字符串，确保二进制位数为四位
        binaryStr = dec2bin(data);
        
        % 检查二进制字符串的长度是否为四位
        if length(binaryStr) > 4
            error('输入的整数二进制表示大于四位。');
        end
        % 检查二进制字符串的长度是否为四位
        if length(binaryStr) < 4
            padding = 4 - length(binaryStr);
            binaryStr = [repmat('0', 1, padding) binaryStr];
        end
        % 提取后二进制数
        B2=binaryStr(2);
        B1=binaryStr(3);
        B0=binaryStr(4);
        diffq=fix(step/8);
        if bin2dec(B2)
            diffq=diffq+step;
        end
        if bin2dec(B1)
            diffq=diffq+fix(step/2);
        end
        if bin2dec(B0)
            diffq=diffq+fix(step/4);
        end
        sign=bin2dec(binaryStr(1:1));

        diffq = (-1)^sign*diffq;
        pre_data = pre_data + diffq; % Get the predicted data according to the data-increment
        index = index + Ml_values_table(data+1);% Convert the binary number "(B2B1B0)_2" to decimal number
        if (pre_data>32767)
            pre_data=32767;
        elseif (pre_data<-32767)
            pre_data=-32767;     % Limit the index in the range of step_sizes_table:(0,49)
        end  
        if (index<=0)
            index=1;
        elseif (index>=89)
            index=89;     % Limit the index in the range of step_sizes_table:(0,49)
        end
        out(i)=pre_data;
    end
end
7、ADPCM编解码：





8、-律非均匀量化编码与解码结果：

与ADPCM编解码相比，每个采样点传输的时候都是4bit传输，但是ADPCM编解码信噪比为15.0760，-律为14.7915，比ADPCM低，说明ADPCM性能更好。





9、其实在编解码函数编写时候，主要是考虑数据的范围，所以需要加很多限制条件。而且由两种编解码方式发现，其实编码就是利用特殊协议（可以是公式），把输入数据映射到一定小范围，解码就是编码的协议反操作。至少对于这两个方式，本质还是把每个采样点都按照一样的规则进行映射，然后成为每个采样点的编码输出。区别在于，-律每个采样点的编解码只取决于采样点输入数据和协议；但是ADPCM每个采样点的编解码需要知道当前状态（位置和pre_data，由上一个采样点决定），此时不用知道上个采样点的状态。

10、总代码：

实际编程还要考虑输入音频的数据，比如的我的数据是-1~1的double(64bit)类型，我需要转化成int16。
还可以改进地方：理论输出的encoded_signal每个采样点是4bit。实际我的代码中输入音频数组长度为24001，encoded_signal是double类型，数组长度为24001，虽然数据大小范围在4bit大小内。
改进：可以参照单片机编码原理，由于matlab没有4bit的类型，最小只有int8类型，可以把前两个采样点数据，凭借成8bit数据，这样得到的encoded_signal数组长度为14001/2+1。解码的时候，取高四位得到第1个采样点code，取低四位得到第2个采样点code。拼接成8bit就是我自己的私密协议（像步长表一样）。当然，如果想自己定义成16bit，就把4个采样点拼接。
clc;
clear;

% 读取音频文件
[y1, fs] = audioread('cut_audio.wav');
% y = [16,32,48,64,80,80,80,64,1024,1024,1024,1024,];

% 将double类型的音频样本转换为int16类型
max_val = max(abs(y1));
scaling_factor = double(intmax('int16')) / max_val;
y_int16 = round(scaling_factor * y1);
y = int16(y_int16);

% %一般来说输入数据范围在16bit,因为StepSizeTable设置的元素范围就是16bit
% y=double_to_int_bits(y,16);
encoded_signal= adpcm_encoder(y);

decoded_signal= decoder(encoded_signal);
decoded_signal=decoded_signal/scaling_factor;
% 计算信噪比
snr_values = calculateSNR(y1, decoded_signal);


% 输出信噪比
disp('ADPCM SNR values(4 bit):');
disp(snr_values);
% 绘制编码后的音频
subplot(2,2,1);
plot(y1);
title('Original Audio');

subplot(2,2,3);
plot(encoded_signal);
title(['Encoded Audio (to\_bit = ', num2str(4), ')']);

subplot(2,2,4);
plot(decoded_signal);
title(['Decoded Audio (to\_bit = ', num2str(4), ')']);

function code = adpcm_encoder(x)    
    Ml_values_table = [-1,-1,-1,-1,2,4,6,8,-1,-1,-1,-1,2,4,6,8];
    step_sizes_table = [7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796, 876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767];    
    ss = step_sizes_table;
    
    % Initialization,index 存储的是上一次预测的差值步长下标, 通过查表可以得到步长,matlab索引值最小是1，不是0
    index = 1;
    % predsample 存储的是上一个解码值, 解码还原时产生的就是这个值
    pre_data = 0;
    B0=zeros(size(x));
    B1=zeros(size(x)); 
    B2=zeros(size(x)); 
    B3=zeros(size(x));
    %编码后的4bit数组code
    code = zeros(size(x));
    
    for i = 1:length(x)
        current_data = x(i);                % input current data
        diff = current_data - pre_data;     % calculate data-increment
        %当前步长
        step = ss(index);
    
        % Calculate the B3,B2,B1,B0 step by step following the References-1 as
        % follows:
        %     let B3 = B2 = B1 = B0 = 0 
        %     if (d(n) < 0)    
        %         then B3 = 1 
        %     d(n) = ABS(d(n)) 
        %     if (d(n) >= ss(n))    
        %         then B2 = 1 and d(n) = d(n) - ss(n) 
        %     if (d(n) >= ss(n) / 2)    
        %         then B1 = 1 and d(n) = d(n) - ss(n) / 2 
        %     if (d(n) >= ss(n) / 4)    
        %         then B0 = 1 L(n) = (10002 * B3) + (1002 * B2) + (102 * B1) + B0   
        
        % 负号编码
        if diff<0
            diff = abs(diff); 
            B3(i) = 1; 
        end

        tmpstep=step;
        diffq=fix(step/8);
        if diff >= tmpstep  
            B2(i) = 1 ;
            diff=diff-tmpstep;
            diffq=diffq+step;
        end
        tmpstep=fix(tmpstep/2);
        if diff >= tmpstep
            B1(i) = 1 ;
            diff=diff-tmpstep;
            diffq=diffq+fix(step/2);
        end
        tmpstep=fix(tmpstep/2);
        if diff >= tmpstep
            B0(i) = 1 ;
            diffq=diffq+fix(step/4);
        end


        L = 8*B3(i) + 4*B2(i) + 2*B1(i) + B0(i); % Convert the binary number "(B3B2B1B0)_2" to decimal number L as output
        code(i) = L;
        
        % % Get the data-increment= based on step_sizes_table and index
        diffq = (-1)^B3(i)*diffq;
        pre_data = pre_data + diffq; % Get the predicted data according to the data-increment
        
        index = index + Ml_values_table(L+1);  % Convert the binary number "(B2B1B0)_2" to decimal number
        if (pre_data>32767)
            pre_data=32767;
        elseif (pre_data<-32767)
            pre_data=-32767;     % Limit the index in the range of step_sizes_table:(0,49)
        end      
        if (index<=0)
            index=1;
        elseif (index>=89)
            index=89;     % Limit the index in the range of step_sizes_table:(0,49)
        end   
    end
end


function [out] = decoder(x)
    Ml_values_table = [-1,-1,-1,-1,2,4,6,8,-1,-1,-1,-1,2,4,6,8];
    step_sizes_table = [7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796, 876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767];    
    ss = step_sizes_table;
    
    out = zeros(size(x));
    % Initialization,index 存储的是上一次预测的差值步长下标, 通过查表可以得到步长
    index = 1;
    % predsample 存储的是上一个解码值, 解码还原时产生的就是这个值
    pre_data = 0;
    % 


    for i = 1:length(x)
        data = x(i);                % input current 4 bit data
        %当前步长
        step = ss(index);
        diffq = fix(step /8);
        
        % 将整数转换为二进制字符串，确保二进制位数为四位
        binaryStr = dec2bin(data);
        
        % 检查二进制字符串的长度是否为四位
        if length(binaryStr) > 4
            error('输入的整数二进制表示大于四位。');
        end
        % 检查二进制字符串的长度是否为四位
        if length(binaryStr) < 4
            padding = 4 - length(binaryStr);
            binaryStr = [repmat('0', 1, padding) binaryStr];
        end
        % 提取后二进制数
        B2=binaryStr(2);
        B1=binaryStr(3);
        B0=binaryStr(4);
        diffq=fix(step/8);
        if bin2dec(B2)
            diffq=diffq+step;
        end
        if bin2dec(B1)
            diffq=diffq+fix(step/2);
        end
        if bin2dec(B0)
            diffq=diffq+fix(step/4);
        end
        sign=bin2dec(binaryStr(1:1));

        diffq = (-1)^sign*diffq;
        pre_data = pre_data + diffq; % Get the predicted data according to the data-increment
        index = index + Ml_values_table(data+1);% Convert the binary number "(B2B1B0)_2" to decimal number
        if (pre_data>32767)
            pre_data=32767;
        elseif (pre_data<-32767)
            pre_data=-32767;     % Limit the index in the range of step_sizes_table:(0,49)
        end  
        if (index<=0)
            index=1;
        elseif (index>=89)
            index=89;     % Limit the index in the range of step_sizes_table:(0,49)
        end
        out(i)=pre_data;
    end
end
function snr = calculateSNR(originalSignal, noisySignal)
    % 计算原始信号的功率
    originalPower = sum(abs(originalSignal).^2) / length(originalSignal);

    % 计算噪声信号的功率
    noisyPower = sum(abs(noisySignal - originalSignal).^2) / length(noisySignal);

    % 计算信噪比（dB）
    snr = 10 * log10(originalPower / noisyPower);
end

11、碎碎念：一个小实验的小题肝了我两个星期，真是服了我自己了。🆒🆒🆒一开始想找官方手册看懂原理自己写代码的，发现还是边看别人代码边看原理图理解快点，虽然都是C和C++写的🤮🤮🤮

​
