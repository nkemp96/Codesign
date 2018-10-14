################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
/home/nicholas/ece522/project/c_code/kmeans_codesign.c 

OBJS += \
./src/kmeans_codesign.o 

C_DEPS += \
./src/kmeans_codesign.d 


# Each subdirectory must supply rules for building sources it contributes
src/kmeans_codesign.o: /home/nicholas/ece522/project/c_code/kmeans_codesign.c
	@echo 'Building file: $<'
	@echo 'Invoking: ARM v7 Linux gcc compiler'
	arm-linux-gnueabihf-gcc -Wall -O0 -g3 -c -fmessage-length=0 -MT"$@" -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


