#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/gpio.h>			// GPIO functions
#include <linux/interrupt.h>	// IRQ code
#include <linux/kmod.h>			// call_usermodehelper

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Roger Miranda");
MODULE_DESCRIPTION("Encender un LED al presionar un botón");
MODULE_VERSION("0.1");

#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)

#define GPIO_LED 	20
#define GPIO_BTN 	26

#define USER		"rogermiranda1000"

static unsigned int irqNumber;
static unsigned int numberPresses = 0;	// store number of presses
static bool	ledOn = false;				// used to invert state of LED

static irq_handler_t  erpi_gpio_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs);

static int enable_pull_up(const char *pin) {
	const char *const pull_up_cmd[] = { "/usr/bin/raspi-gpio", "set", pin, "pu" };
	const char *envp[] = { "SHELL=/bin/bash", "HOME=/home/" USER, "USER=" USER, "PATH=/sbin:/usr/sbin:/bin:/usr/bin", "PWD=/home/" USER, NULL };
	return call_usermodehelper(pull_up_cmd[0], (char**)pull_up_cmd, (char**)envp, UMH_WAIT_EXEC);
}

static int __init erpi_gpio_init(void) {
	int result;
	
	// LED
	gpio_request(GPIO_LED, "sysfs");			// request GPIO
	gpio_direction_output(GPIO_LED, ledOn);		// set in output mode and on
	ledOn = true;
	gpio_export(GPIO_LED, false);				// appears in /sys/class/gpio; false prevents direction change

	// BTN
	gpio_request(GPIO_BTN, "sysfs");
	gpio_direction_input(GPIO_BTN);				// set up as input
	gpio_export(GPIO_BTN, false);
	// enable pull-up
	result = enable_pull_up(STR(GPIO_BTN));
	if (result != 0) return result;

	// interrupt entry point
	irqNumber = gpio_to_irq(GPIO_BTN);				// map GPIO to IRQ number
	result = request_irq(irqNumber,					// interrupt number requested
			(irq_handler_t) erpi_gpio_irq_handler,	// handler function
			IRQF_TRIGGER_FALLING,					// on falling edge
			"erpi_gpio_handler",					// used in /proc/interrupts
			NULL);									// *dev_id for shared interrupt lines
	return result;
}

static void __exit erpi_gpio_exit(void) {
	printk(KERN_INFO "GPIO_TEST: pressed %d times\n", numberPresses);
	gpio_set_value(GPIO_LED, 0);	// turn the LED off
	gpio_unexport(GPIO_LED);		// unexport the GPIO
	free_irq(irqNumber, NULL);		// free the IRQ number; no *dev_id
	gpio_unexport(GPIO_BTN);
	gpio_free(GPIO_LED);			// free the GPIO [free of gpio_request]
	gpio_free(GPIO_BTN);
}

static irq_handler_t erpi_gpio_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs) {
	ledOn = !ledOn;
	gpio_set_value(GPIO_LED, ledOn);
	numberPresses++;
	return (irq_handler_t) IRQ_HANDLED; // announce IRQ handled
}

module_init(erpi_gpio_init);
module_exit(erpi_gpio_exit);