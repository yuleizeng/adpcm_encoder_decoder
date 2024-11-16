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
encoded_signal= adpcm_encoder(y);

decoded_signal= decoder(encoded_signal);
decoded_signal=decoded_signal/scaling_factor;
% 计算信噪比
snr_values = calculateSNR(y1, decoded_signal);
% 指定文件名
filename = 'adpcm (bit=4).wav' ;
 
% 保存WAV文件
audiowrite(filename, decoded_signal, fs);    

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

