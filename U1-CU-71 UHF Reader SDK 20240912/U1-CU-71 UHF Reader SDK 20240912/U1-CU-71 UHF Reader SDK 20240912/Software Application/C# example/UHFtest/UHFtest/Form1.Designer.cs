namespace UHFtest
{
    partial class Form1
    {
        /// <summary>
        /// 必需的设计器变量。
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// 清理所有正在使用的资源。
        /// </summary>
        /// <param name="disposing">如果应释放托管资源，为 true；否则为 false。</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows 窗体设计器生成的代码

        /// <summary>
        /// 设计器支持所需的方法 - 不要
        /// 使用代码编辑器修改此方法的内容。
        /// </summary>
        private void InitializeComponent()
        {
            this.btn_test = new System.Windows.Forms.Button();
            this.listBox1 = new System.Windows.Forms.ListBox();
            this.btn_ReadMultipleEPC = new System.Windows.Forms.Button();
            this.SuspendLayout();
            // 
            // btn_test
            // 
            this.btn_test.Location = new System.Drawing.Point(467, 108);
            this.btn_test.Name = "btn_test";
            this.btn_test.Size = new System.Drawing.Size(114, 32);
            this.btn_test.TabIndex = 0;
            this.btn_test.Text = "Test";
            this.btn_test.UseVisualStyleBackColor = true;
            this.btn_test.Click += new System.EventHandler(this.btn_test_Click);
            // 
            // listBox1
            // 
            this.listBox1.FormattingEnabled = true;
            this.listBox1.ItemHeight = 12;
            this.listBox1.Location = new System.Drawing.Point(13, 19);
            this.listBox1.Name = "listBox1";
            this.listBox1.Size = new System.Drawing.Size(433, 364);
            this.listBox1.TabIndex = 1;
            // 
            // btn_ReadMultipleEPC
            // 
            this.btn_ReadMultipleEPC.Location = new System.Drawing.Point(467, 179);
            this.btn_ReadMultipleEPC.Name = "btn_ReadMultipleEPC";
            this.btn_ReadMultipleEPC.Size = new System.Drawing.Size(115, 32);
            this.btn_ReadMultipleEPC.TabIndex = 2;
            this.btn_ReadMultipleEPC.Text = "Read multiple EPC";
            this.btn_ReadMultipleEPC.UseVisualStyleBackColor = true;
            this.btn_ReadMultipleEPC.Click += new System.EventHandler(this.btn_ReadMultipleEPC_Click);
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 12F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(594, 404);
            this.Controls.Add(this.btn_ReadMultipleEPC);
            this.Controls.Add(this.listBox1);
            this.Controls.Add(this.btn_test);
            this.Name = "Form1";
            this.Text = "UHFtest";
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.Button btn_test;
        private System.Windows.Forms.ListBox listBox1;
        private System.Windows.Forms.Button btn_ReadMultipleEPC;
    }
}

