#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/gpio.h>			// GPIO functions
#include <linux/interrupt.h>	// IRQ code
#include <linux/kmod.h>			// call_usermodehelper
#include <linux/types.h>		// uint_32
//#include "gpio_manager.h"

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Roger Miranda");
MODULE_DESCRIPTION("Encender LEDs y ejecutar programas al presionar botones");
MODULE_VERSION("0.1");

#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)

#define GPIO_LED1 	16
#define GPIO_LED2 	20

#define BTN_NUM		(sizeof(btns)/sizeof(Button))
#define BTN_DEBOUNCE 0

#define PROGRAM_NAME "F1"
#define USER		"rogermiranda1000"

typedef struct {
	uint32_t gpio; // btn GPIO
	
	// events
	const char *const cmd;
	
	uint32_t led_gpio;
	bool toggle_on;
	
	// program variables
	uint32_t irqNumber;
	uint32_t numPresses;
} Button;

static Button btns[] = {
	(Button){21,  "/home/rogermiranda1000/lkm/script1.sh", GPIO_LED1, true, 0, 0},
	(Button){26, "/home/rogermiranda1000/lkm/script1.sh", GPIO_LED1, false, 0, 0},
	(Button){13, "/home/rogermiranda1000/lkm/script1.sh", GPIO_LED2, true, 0, 0},
	(Button){6, "/home/rogermiranda1000/lkm/script1.sh", GPIO_LED2, false, 0, 0}
};

static irq_handler_t gpio_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs);

static int enable_pull_up(const char *pin) {
	// TODO {"/home/rogermiranda1000/lkm/script1.sh", NULL}
	const char *const pull_up_cmd[] = { "/usr/bin/raspi-gpio", "set", pin, "pu" };
	const char *envp[] = { "SHELL=/bin/bash", "HOME=/home/" USER, "PWD=/home/" USER, NULL };
	return call_usermodehelper(pull_up_cmd[0], (char**)pull_up_cmd, (char**)envp, UMH_WAIT_EXEC);
}

static int setup_btn(uint8_t index) {
	int result;
	uint32_t gpio;
	
	gpio = btns[index].gpio;
	gpio_request(gpio, "sysfs");
	gpio_direction_input(gpio);
	gpio_export(gpio, false);
	//setGpioPull(gpio, PULL_UP); // TODO enable pull-up
#if (BTN_DEBOUNCE>0)
	gpio_set_debounce(gpio, BTN_DEBOUNCE);
#endif
	
	// interrupt entry point
	btns[index].irqNumber = gpio_to_irq(gpio);
	result = request_irq(btns[index].irqNumber,		// interrupt number
			(irq_handler_t) gpio_irq_handler,		// handler function
			IRQF_TRIGGER_FALLING,					// on falling edge
			"erpi_gpio_handler",					// used in /proc/interrupts
			NULL);									// *dev_id for shared interrupt lines
			
	printk(KERN_INFO PROGRAM_NAME ": GPIO%d setted as pull-up button under IRQ%d", gpio, btns[index].irqNumber);
	return result;
}

static int __init erpi_gpio_init(void) {
	int result = 0;
	uint8_t x;
	
	printk(KERN_INFO PROGRAM_NAME ": enabling kernel module...");
	
	// LED
	gpio_request(GPIO_LED1, "sysfs");			// request GPIO
	gpio_direction_output(GPIO_LED1, 0);		// set in output mode and off
	gpio_export(GPIO_LED1, false);				// appears in /sys/class/gpio; false prevents direction change
	
	gpio_request(GPIO_LED2, "sysfs");
	gpio_direction_output(GPIO_LED2, 0);
	gpio_export(GPIO_LED2, false);

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
	
	// free interrupt & btn
	for (x = 0; x < BTN_NUM; x++) {
		free_irq(btns[x].irqNumber, NULL); // free the IRQ number; no *dev_id
		gpio_unexport(btns[x].gpio);
		gpio_free(btns[x].gpio);
	}
	
	// turn off LEDs & free
	gpio_set_value(GPIO_LED1, 0);
	gpio_unexport(GPIO_LED1);
	gpio_free(GPIO_LED1);
	
	gpio_set_value(GPIO_LED2, 0);
	gpio_unexport(GPIO_LED2);
	gpio_free(GPIO_LED2);
}

static irq_handler_t gpio_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs) {
	uint8_t x;
	const char *args[] = { btns[0].cmd, NULL }; // TODO tmp
	const char *envp[] = { "SHELL=/bin/bash", "HOME=/home/" USER, "PWD=/home/" USER, NULL };
	
	for (x = 0; x < BTN_NUM; x++) {
		if (irq != btns[x].irqNumber) continue;
		gpio_set_value(btns[x].led_gpio, btns[x].toggle_on);
		//args[0] = btns[x].cmd;
		call_usermodehelper(args[0], (char**)args, (char**)envp, UMH_WAIT_EXEC);
		break;
	}
	return (irq_handler_t) IRQ_HANDLED; // announce IRQ handled
}

module_init(erpi_gpio_init);
module_exit(erpi_gpio_exit);