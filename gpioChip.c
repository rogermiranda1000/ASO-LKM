#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <ctype.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>

// From https://github.com/RPi-Distro/raspi-gpio/blob/master/raspi-gpio.c


#define PULL_UNSET  -1
#define PULL_NONE    0
#define PULL_DOWN    1
#define PULL_UP      2

#define GPIO_BASE_OFFSET 0x00200000
#define GPPUD        37
#define GPPUDCLK0    38

struct gpio_chip
{
    const char *name;
    uint32_t reg_base;
    uint32_t reg_size;
    unsigned int gpio_count;
    unsigned int fsel_count;
    const char *info_header;
    const char **alt_names;
    const int *default_pulls;

    int (*get_level)(struct gpio_chip *chip, unsigned int gpio);
    int (*get_fsel)(struct gpio_chip *chip, unsigned int gpio);
    int (*get_pull)(struct gpio_chip *chip, unsigned int gpio);
    int (*set_level)(struct gpio_chip *chip, unsigned int gpio, int level);
    int (*set_fsel)(struct gpio_chip *chip, unsigned int gpio, int fsel);
    int (*set_pull)(struct gpio_chip *chip, unsigned int gpio, int pull);
    int (*next_reg)(int reg);

    volatile uint32_t *base;
};

/*
struct gpio_chip gpio_chip_2835 =
{
    "bcm2835",
    0x00200000,
    0x1000,
    54,
    6,
    "GPIO, DEFAULT PULL, ALT0, ALT1, ALT2, ALT3, ALT4, ALT5",
    gpio_alt_names_2835,
    gpio_default_pullstate_2835,
    bcm2835_get_level,
    bcm2835_get_fsel,
    bcm2835_get_pull,
    bcm2835_set_level,
    bcm2835_set_fsel,
    bcm2835_set_pull,
    bcm2835_next_reg,
};

struct gpio_chip gpio_chip_2711 =
{
    "bcm2711",
    0x00200000,
    0x1000,
    54,
    6,
    "GPIO, DEFAULT PULL, ALT0, ALT1, ALT2, ALT3, ALT4, ALT5",
    gpio_alt_names_2711,
    gpio_default_pullstate_2835,
    bcm2835_get_level,
    bcm2835_get_fsel,
    bcm2711_get_pull,
    bcm2835_set_level,
    bcm2835_set_fsel,
    bcm2711_set_pull,
    bcm2711_next_reg,
};
*/

uint32_t getGpioRegBase(void) {
    const char *revision_file = "/proc/device-tree/system/linux,revision";
    uint8_t revision[4] = { 0 };
    uint32_t cpu = 0;
    FILE *fd;

    if ((fd = fopen(revision_file, "rb")) == NULL)
    {
        printf("Can't open '%s'\n", revision_file);
    }
    else
    {
        if (fread(revision, 1, sizeof(revision), fd) == 4)
            cpu = (revision[2] >> 4) & 0xf;
        else
            printf("Revision data too short\n");

        fclose(fd);
    }

    printf("CPU: %d\n", cpu);
    switch (cpu) {
		case 0: // BCM2835 [Pi 1 A; Pi 1 B; Pi 1 B+; Pi Zero; Pi Zero W]
			//chip = &gpio_chip_2835;
			return 0x20000000 + GPIO_BASE_OFFSET;
		case 1: // BCM2836 [Pi 2 B]
		case 2: // BCM2837 [Pi 3 B; Pi 3 B+; Pi 3 A+]
			//chip = &gpio_chip_2835;
			return 0x3f000000 + GPIO_BASE_OFFSET;
		case 3: // BCM2711 [Pi 4 B]
			//chip = &gpio_chip_2711;
			return 0xfe000000 + GPIO_BASE_OFFSET;
		default:
			printf("Unrecognised revision code\n");
			exit(1);
    }
}

volatile uint32_t *getBase(uint32_t reg_base) {
	int fd;
	if ((fd = open ("/dev/mem", O_RDWR | O_SYNC | O_CLOEXEC) ) < 0) return NULL;
	return (uint32_t *)mmap(0, /*chip->reg_size*/ 0x1000,
								  PROT_READ|PROT_WRITE, MAP_SHARED,
								  fd, reg_base);
}

void setPull(volatile uint32_t *base, unsigned int gpio, int pull) {
    int clkreg = GPPUDCLK0 + (gpio / 32);
    int clkbit = 1 << (gpio % 32);

    base[GPPUD] = pull;
    usleep(10);
    base[clkreg] = clkbit;
    usleep(10);
    base[GPPUD] = 0;
    usleep(10);
    base[clkreg] = 0;
    usleep(10);
}

/*static int bcm2711_set_pull(struct gpio_chip *chip, unsigned int gpio, int pull)
{
    int reg = GPPUPPDN0 + (gpio / 16);
    int lsb = (gpio % 16) * 2;

    if (gpio >= chip->gpio_count)
        return -1;

    switch (pull)
    {
    case PULL_NONE:
        pull = 0;
        break;
    case PULL_UP:
        pull = 1;
        break;
    case PULL_DOWN:
        pull = 2;
        break;
    default:
        return -1;
    }

    chip->base[reg] = (chip->base[reg] & ~(3 << lsb)) | (pull << lsb);

    return 0;
}*/

int main() {
	uint32_t reg_base = getGpioRegBase();
	volatile uint32_t *base = getBase(reg_base);
	if (base == NULL || base == (uint32_t *)-1) {
	printf("Base error");
		return 1;
	}
	printf("Base: %p\n", base);
	setPull(base, 26, PULL_UP);
	return 0;
}

