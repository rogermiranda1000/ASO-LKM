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
#include <errno.h>

// From https://github.com/RPi-Distro/raspi-gpio/blob/master/raspi-gpio.c


#define PULL_UNSET	-1
#define PULL_NONE	0
#define PULL_DOWN	1
#define PULL_UP		2

#define GPIO_BASE_OFFSET 0x00200000
#define GPPUD		37
#define GPPUDCLK0	38
#define BASE_READ	0x1000
#define BASE_SIZE	(BASE_READ/sizeof(uint32_t))

uint32_t getGpioRegBase(void) {
    const char *revision_file = "/proc/device-tree/system/linux,revision";
    uint8_t revision[4] = { 0 };
    uint32_t cpu = 0;
    FILE *fd;

    if ((fd = fopen(revision_file, "rb")) == NULL) {
        printf("Can't open '%s'\n", revision_file);
		exit(EXIT_FAILURE);
    }
    else {
        if (fread(revision, 1, sizeof(revision), fd) == 4) cpu = (revision[2] >> 4) & 0xf;
        else {
			printf("Revision data too short\n");
			exit(EXIT_FAILURE);
		}

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

int writeBase(uint32_t reg_base, uint32_t offset, uint32_t data) {
	int fd;
	if ((fd = open("/dev/mem", O_RDWR | O_SYNC | O_CLOEXEC) ) < 0) return -1;
	
	if (lseek(fd, reg_base+offset, SEEK_SET) == -1) return -2;
	if (write(fd, (void*)&data, sizeof(uint32_t)) != sizeof(uint32_t)) return -3;
	if (close(fd) == -1) return -4;
	return 0;
}

int setPull(unsigned int gpio, int pull) {
	int r;
    int clkreg = GPPUDCLK0 + (gpio / 32);
    int clkbit = 1 << (gpio % 32);
	uint32_t reg_base = getGpioRegBase();

	r = writeBase(reg_base, GPPUD, pull); // base[GPPUD] = pull
    if (r < 0) return r;
	usleep(10);
	r = writeBase(reg_base, clkreg, clkbit); // base[clkreg] = clkbit
    if (r < 0) return r;
    usleep(10);
	r = writeBase(reg_base, GPPUD, 0); // base[GPPUD] = 0
    if (r < 0) return r;
    usleep(10);
	r = writeBase(reg_base, clkreg, 0); // base[clkreg] = 0
    usleep(10);
	return r;
}

int main(int argc, char *argv[]) {
	int gpio, r;
	
	if (argc!=2) {
		printf("GPIO pin needed!\n");
		return 1;
	}
	
	gpio = atoi(argv[1]);
	printf("Enabling pull-up on GPIO%d...\n", gpio);
	r = setPull(gpio, PULL_UP);
	printf("Return value: %d\n", r);
	if (r != 0) printf("%s\n", strerror(errno));
	return r;
}

