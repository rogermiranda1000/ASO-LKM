
/**
 * It enables the pull-ups
 * @author https://github.com/RPi-Distro/raspi-gpio/blob/master/raspi-gpio.c
 * @author Roger Miranda
 */

#include <linux/types.h>	// uint_32
#include <linux/fs.h>		// filp_open/filp_close
#include <linux/delay.h>	// udelay
#include <linux/io.h>		// ioremap?

#define PULL_DOWN    1
#define PULL_UP      2


/**
 * Equivalent to 'raspi-gpio set <gpio> <pu/pd>'
 * @param gpio Valid GPIO pin
 * @param pull PULL_DOWN/PULL_UP
 */
static int setGpioPull(uint32_t gpio, int pull);

/****************************
 ***   PRIVATE FUNCTIONS  ***
 ****************************/

#define GPIO_BASE_OFFSET 0x00200000
#define GPPUD        37
#define GPPUDCLK0    38

static uint32_t getGpioRegBase(bool *error) {
    uint8_t revision[4] = { 0 };
    uint32_t cpu = 0;
	struct file *fd;
    ssize_t rc = 0;

	if (IS_ERR(( fd = filp_open("/proc/device-tree/system/linux,revision", O_RDONLY | O_SYNC | O_CLOEXEC, 0) ))) {
		*error = true;
		return 0;
	}
	
	if ((rc = kernel_read(fd, revision, sizeof(revision), 0)) == 4) cpu = (revision[2] >> 4) & 0xf;
	else {
		*error = true;
		return 0;
	}

	filp_close(fd, NULL);

	*error = false;
    switch (cpu) {
		case 0: // BCM2835 [Pi 1 A; Pi 1 B; Pi 1 B+; Pi Zero; Pi Zero W]
			return 0x20000000 + GPIO_BASE_OFFSET;
		case 1: // BCM2836 [Pi 2 B]
		case 2: // BCM2837 [Pi 3 B; Pi 3 B+; Pi 3 A+]
			return 0x3f000000 + GPIO_BASE_OFFSET;
		case 3: // BCM2711 [Pi 4 B]
			return 0xfe000000 + GPIO_BASE_OFFSET;
		default:
			*error = true;
			return 0;
    }
}

static void setPull(volatile uint32_t *base, uint32_t gpio, int pull) {
	int clkreg = GPPUDCLK0 + (gpio / 32);
	int clkbit = 1 << (gpio % 32);

	base[GPPUD] = pull;
	udelay(10);
	base[clkreg] = clkbit;
	udelay(10);
	base[GPPUD] = 0;
	udelay(10);
	base[clkreg] = 0;
	udelay(10);
}

static int setGpioPull(uint32_t gpio, int pull) {
	bool error;
	uint32_t reg_base;
	volatile uint32_t *base;
	
	reg_base = getGpioRegBase(&error);
	if (error) return -1;
	base = (uint32_t*)ioremap(reg_base, 0x1000);
	if (base == NULL || base == (uint32_t*)-1) return -1;
	setPull(base, gpio, pull);
	iounmap(base);
	
	return 0;
}