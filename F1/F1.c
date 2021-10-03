#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/gpio.h>			// GPIO functions
#include <linux/interrupt.h>	// IRQ code
#include <linux/kmod.h>			// call_usermodehelper
#include <linux/types.h>		// uint_32
#include "gpio_manager.h"

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Roger Miranda");
MODULE_DESCRIPTION("Encender LEDs y ejecutar programas al presionar botones");
MODULE_VERSION("0.1");

#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)

#define GPIO_LED1 	20
#define GPIO_LED2 	16

#define BTN_NUM		4
#define BTN_DEBOUNCE 0
#define GPIO_BTN1 	6
#define GPIO_BTN2 	26
#define GPIO_BTN3 	13
#define GPIO_BTN4 	21

#define PROGRAM_NAME "F1"
#define USER		"rogermiranda1000"
#define PATH		"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games"

static uint32_t irqNumber[BTN_NUM];
static uint8_t irqIndex = 0;

static uint32_t numberPresses[BTN_NUM] = {0}; // store number of presses

static bool	ledStates[2] = {false, false}; // used to invert state of LED

static irq_handler_t erpi_gpio_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs);

static int enable_pull_up(const char *pin) {
	const char *const pull_up_cmd[] = { "/usr/bin/raspi-gpio", "set", pin, "pu" };
	const char *envp[] = { "SHELL=/bin/bash", "HOME=/home/" USER, "USER=" USER, "PATH=" PATH, "PWD=/home/" USER, NULL };
	return call_usermodehelper(pull_up_cmd[0], (char**)pull_up_cmd, (char**)envp, UMH_WAIT_EXEC);
}

static int setup_btn(uint32_t gpio, const char *gpio_s, irq_handler_t handler) {
	int result;
	
	gpio_request(gpio, "sysfs");
	gpio_direction_input(gpio);
	gpio_export(gpio, false);
	setGpioPull(gpio, PULL_UP); // enable pull-up
#if (BTN_DEBOUNCE>0)
	gpio_set_debounce(gpio, BTN_DEBOUNCE);
#endif
	
	// enable pull-up
	/*result = enable_pull_up(gpio_s);
	if (result != 0) return result;*/
	
	// interrupt entry point
	irqNumber[irqIndex] = gpio_to_irq(gpio);
	result = request_irq(irqNumber[irqIndex],		// interrupt number
			handler,								// handler function
			IRQF_TRIGGER_FALLING,					// on falling edge
			"erpi_gpio_handler",					// used in /proc/interrupts
			NULL);									// *dev_id for shared interrupt lines
	irqIndex++;
	return result;
}

static void free_btn(uint32_t gpio) {
	gpio_unexport(gpio);
	gpio_free(gpio);
}

static int __init erpi_gpio_init(void) {
	int result;
	
	// LED
	gpio_request(GPIO_LED1, "sysfs");			// request GPIO
	gpio_direction_output(GPIO_LED1, ledStates[0]);	// set in output mode and on
	ledStates[0] = true;
	gpio_export(GPIO_LED1, false);				// appears in /sys/class/gpio; false prevents direction change
	
	gpio_request(GPIO_LED2, "sysfs");			// request GPIO
	gpio_direction_output(GPIO_LED2, ledStates[1]);	// set in output mode and on
	ledStates[1] = true;
	gpio_export(GPIO_LED2, false);				// appears in /sys/class/gpio; false prevents direction change

	// BTN
	result = setup_btn(GPIO_BTN1, STR(GPIO_BTN1), (irq_handler_t)erpi_gpio_irq_handler);
	if (result != 0) return result;
	result = setup_btn(GPIO_BTN2, STR(GPIO_BTN2), (irq_handler_t)erpi_gpio_irq_handler);
	if (result != 0) return result;
	result = setup_btn(GPIO_BTN3, STR(GPIO_BTN3), (irq_handler_t)erpi_gpio_irq_handler);
	if (result != 0) return result;
	result = setup_btn(GPIO_BTN4, STR(GPIO_BTN4), (irq_handler_t)erpi_gpio_irq_handler);
	return result;
}

static void __exit erpi_gpio_exit(void) {
	uint8_t x;
	
	printk(KERN_INFO PROGRAM_NAME ": shutting down...");
	
	// free interrupts
	for (x = 0; x < BTN_NUM; x++) free_irq(irqNumber[x], NULL); // free the IRQ number; no *dev_id
	
	// free btn
	free_btn(GPIO_BTN1);
	free_btn(GPIO_BTN2);
	free_btn(GPIO_BTN3);
	free_btn(GPIO_BTN4);
	
	// free LEDs
	gpio_set_value(GPIO_LED1, 0);	// turn the LED off
	gpio_unexport(GPIO_LED1);
	gpio_free(GPIO_LED1);
	
	gpio_set_value(GPIO_LED2, 0);	// turn the LED off
	gpio_unexport(GPIO_LED2);
	gpio_free(GPIO_LED2);
}

static irq_handler_t erpi_gpio_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs) {
	ledStates[0] = !ledStates[0];
	ledStates[1] = !ledStates[0];
	gpio_set_value(GPIO_LED1, ledStates[0]);
	gpio_set_value(GPIO_LED2, ledStates[1]);
	numberPresses[0]++;
	numberPresses[1]++;
	return (irq_handler_t) IRQ_HANDLED; // announce IRQ handled
}

module_init(erpi_gpio_init);
module_exit(erpi_gpio_exit);