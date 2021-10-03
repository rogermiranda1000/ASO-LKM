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

#define BTN_NUM		(sizeof(btns)/sizeof(Button))
#define BTN_DEBOUNCE 0

#define PROGRAM_NAME "F1"
#define USER		"rogermiranda1000"

typedef struct {
	uint32_t gpio,
	const char *const *const pull_up_cmd,
	uint32_t irqNumber,
	uint32_t numPresses
} Button;

static Button btns[] = {
	(Button){6, {"/home/rogermiranda1000/lkm/script1.sh", NULL}, 0, 0},
	(Button){26, {"/home/rogermiranda1000/lkm/script1.sh", NULL}, 0, 0},
	(Button){13, {"/home/rogermiranda1000/lkm/script1.sh", NULL}, 0, 0},
	(Button){21, {"/home/rogermiranda1000/lkm/script1.sh", NULL}, 0, 0}
};

static bool	ledStates[2] = {false, false}; // used to invert state of LED

static irq_handler_t gpio_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs);

static int enable_pull_up(const char *pin) {
	const char *const pull_up_cmd[] = { "/usr/bin/raspi-gpio", "set", pin, "pu" };
	const char *envp[] = { "SHELL=/bin/bash", "HOME=/home/" USER, "PWD=/home/" USER, NULL };
	return call_usermodehelper(pull_up_cmd[0], (char**)pull_up_cmd, (char**)envp, UMH_WAIT_EXEC);
}

static int setup_btn(uint8_t index) {
	int result;
	
	gpio_request(btns[index].gpio, "sysfs");
	gpio_direction_input(btns[index].gpio);
	gpio_export(btns[index].gpio, false);
	setGpioPull(btns[index].gpio, PULL_UP); // enable pull-up
#if (BTN_DEBOUNCE>0)
	gpio_set_debounce(btns[index].gpio, BTN_DEBOUNCE);
#endif
	
	// interrupt entry point
	btns[index].irqNumber = gpio_to_irq(btns[index].gpio);
	result = request_irq(btns[index].irqNumber,		// interrupt number
			(irq_handler_t) gpio_irq_handler,		// handler function
			IRQF_TRIGGER_FALLING,					// on falling edge
			"erpi_gpio_handler",					// used in /proc/interrupts
			NULL);									// *dev_id for shared interrupt lines
	return result;
}

static void free_btn(uint32_t gpio) {
	gpio_unexport(gpio);
	gpio_free(gpio);
}

static int __init erpi_gpio_init(void) {
	int result = 0;
	uint8_t x;
	
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
	for (x = 0; x < BTN_NUM; x++) {
		result = setup_btn(x);
		if (result != 0) return result;
	}
	return result;
}

static void __exit erpi_gpio_exit(void) {
	uint8_t x;
	
	printk(KERN_INFO PROGRAM_NAME ": shutting down...");
	
	// free interrupts
	for (x = 0; x < BTN_NUM; x++) free_irq(btns[x].irqNumber, NULL); // free the IRQ number; no *dev_id
	
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

static irq_handler_t gpio_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs) {
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