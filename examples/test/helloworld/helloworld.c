#include "../common/util.h"
#include "../common/xprintf.h"


void  timer_callback(void)
{
  uint64_t curr_time = timer_read();
  uint32_t curr_time_high = curr_time >> 32;
  uint32_t curr_time_low = curr_time &0xFFFFFFFF;
  xprintf("Timer interrupt!, high =%D, low=%D \n", curr_time_high, curr_time_low);    
}

void fun(void)
{
	put_str("call function!\n");
	for(uint32_t i = 100; i >= 10; i-=1)
	{
		xprintf("num-countdown:%Dover\n", i);
	}
}

int main(int argc, char **argv) 
{

  xprintf("Hello simple system\n");
  put_char('\n');
  put_char('\n');
  timer_enable(200000, timer_callback);
  put_str("Enabled the timer\n");
  while(1)
  {
  	for(uint16_t i = 0; i <= 10; i=i+1)
  	{
  		xprintf("Num: %D\n", i*i);
		if(i <= 5)
		{
			put_str("Tock!\n");
		}
		else
		{
			put_str("Untock!\n");
			fun();
		}
  	}
  }
  
  return 0;
}
