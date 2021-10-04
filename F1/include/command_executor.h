#include <linux/slab.h> 		// kmalloc/kfree
#include <linux/mutex.h> 		// DEFINE_MUTEX/mutex_lock/mutex_unlock
#include <linux/workqueue.h> 	// schedule_work
#include <linux/kmod.h>			// call_usermodehelper

#define MAX_CMD_LEN 	45
#define USER			"rogermiranda1000"

#ifdef USER
	#define HOME "/home/" USER
#else
	#define HOME "/"
#endif

struct work_cont {
	struct work_struct real_work;
	char cmd[MAX_CMD_LEN];
};

struct work_cont *execwq;

static void cmdexec_worker(struct work_struct *work) {
	const char *argv[] = { NULL, NULL };
	const char *envp[] = { "HOME=" HOME, /*"PWD=" HOME, "SHELL=/bin/bash", "PATH=/sbin:/bin:/usr/sbin:/usr/bin",*/ NULL };
	
	struct work_cont *c_ptr = container_of(work, struct work_cont, real_work);
	set_current_state(TASK_INTERRUPTIBLE);

	argv[0] = c_ptr->cmd;

	call_usermodehelper(argv[0], (char**)argv, (char**)envp, UMH_WAIT_PROC);

	return;
}

DEFINE_MUTEX(cmd_mutex);

/**
 * It runs a command
 * @param cmd Command to run
 */
static void call_cmd(const char *const cmd) {
	mutex_lock(&cmd_mutex);
	strncpy(execwq->cmd, cmd, MAX_CMD_LEN);
	mutex_unlock(&cmd_mutex);

	schedule_work(&execwq->real_work);
}

/**
 * It allocates the command_executor memory
 */
static void command_executor_init(void) {
	execwq = kmalloc(sizeof(struct work_cont), GFP_KERNEL);
	INIT_WORK(&execwq->real_work, cmdexec_worker);
}

/**
 * It frees the command_executor memory
 */
static void command_executor_exit(void) {
	flush_work(&execwq->real_work);
	kfree(execwq);
}